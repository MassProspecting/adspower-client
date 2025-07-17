require 'uri'
require 'net/http'
require 'json'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'
require 'fileutils'

class AdsPowerClient  
    CLOUD_API_BASE = 'https://api.adspower.com/v1'

    # reference: https://localapi-doc-en.adspower.com/
    # reference: https://localapi-doc-en.adspower.com/docs/Rdw7Iu
    attr_accessor :key, :port, :server_log, :adspower_listener, :adspower_default_browser_version, :cloud_token

    # control over the drivers created, in order to not create the same driver twice and not generate memory leaks.
    # reference: https://github.com/leandrosardi/adspower-client/issues/4
    @@drivers = {}

    LOCK_FILE = '/tmp/adspower_api_lock'

    def initialize(h={})
        self.key = h[:key] # mandatory
        self.port = h[:port] || '50325'
        self.server_log = h[:server_log] || '~/adspower-client.log'
        self.adspower_listener = h[:adspower_listener] || 'http://127.0.0.1'
        
        # DEPRECATED
        self.adspower_default_browser_version = h[:adspower_default_browser_version] || '116'

        # PENDING
        self.cloud_token = h[:cloud_token]
    end

    # Acquire the lock
    def acquire_lock
        @lockfile ||= File.open(LOCK_FILE, File::CREAT | File::RDWR)
        @lockfile.flock(File::LOCK_EX)
    end

    # Release the lock
    def release_lock
        @lockfile.flock(File::LOCK_UN) if @lockfile
    end

    # Wrapper method for critical sections
    def with_lock
        acquire_lock
        yield
    ensure
        release_lock
    end

    # Return an array of PIDs of all the adspower_global processes running on the local computer.
    def server_pids
        `ps aux | grep "adspower_global" | grep -v grep | awk '{print $2}'`.split("\n")
    end

    # Run async command to start AdsPower server in headless mode.
    # Wait up to 10 seconds to start the server, or raise an exception.
    def server_start(timeout=30)
        `xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' /usr/bin/adspower_global --headless=true --api-key=#{self.key.to_s} --api-port=#{self.port.to_s} > #{self.server_log} 2>&1 &`
        # wait up to 10 seconds to start the server
        timeout.times do
            break if self.online?
            sleep(1)
        end
        # add a delay of 5 more seconds
        sleep(5)
        # raise an exception if the server is not running
        raise "Error: the server is not running" if self.online? == false
        return
    end

    # Kill all the adspower_global processes running on the local computer.
    def server_stop
        with_lock do
            self.server_pids.each { |pid|
                `kill -9 #{pid}`
            }
        end
        return
    end

    # Send a GET request to "#{url}/status" and return true if it responded successfully.
    def online?
        with_lock do
            begin
                url = "#{self.adspower_listener}:#{port}/status"
                uri = URI.parse(url)
                res = Net::HTTP.get(uri)
                return JSON.parse(res)['msg'] == 'success'
            rescue => e
                return false
            end
        end
    end

    # Count current profiles (optionally filtered by group)
    def profile_count(group_id: nil)
        count = 0
        page  = 1

        loop do
        params = { page: page, limit: 100 }
        params[:group_id] = group_id if group_id
        url   = "#{adspower_listener}:#{port}/api/v2/browser-profile/list"
        res   = BlackStack::Netting.call_post(url, params)
        data  = JSON.parse(res.body)
        raise "Error listing profiles: #{data['msg']}" unless data['code'] == 0

        list = data['data']['list']
        count += list.size
        break if list.size < 100

        page += 1
        end

        count
    end

    # Return a hash with:
    #  • :limit     ⇒ total profile slots allowed (-1 = unlimited)
    #  • :used      ⇒ number of profiles currently created
    #  • :remaining ⇒ slots left (nil if unlimited)
    # Fetch your real profile quota from the Cloud API
    def cloud_profile_quota
        uri = URI("#{CLOUD_API_BASE}/account/get_info")
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Bearer #{self.cloud_token}"

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(req)
        end
        data = JSON.parse(res.body)
        raise "Cloud API error: #{data['msg']}" unless data['code'] == 0

        allowed = data['data']['total_profiles_allowed'].to_i
        used    = data['data']['profiles_used'].to_i
        remaining = allowed < 0 ? nil : (allowed - used)

        { limit:     allowed,
        used:      used,
        remaining: remaining }
    end # cloud_profile_quota

    # Create a new user profile via API call and return the ID of the created user.
    def create
        with_lock do
            url = "#{self.adspower_listener}:#{port}/api/v1/user/create"
            body = {
                'group_id' => '0',
                'proxyid' => '1',
                'fingerprint_config' => {
                    'browser_kernel_config' => {"version": self.adspower_default_browser_version, "type": "chrome"}
                }
            }
            # API call
            res = BlackStack::Netting.call_post(url, body)
            ret = JSON.parse(res.body)
            raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
            ret['data']['id']
        end
    end # def create

    # Create a new desktop profile with custom name, proxy, and fingerprint settings
    #
    # @param name            [String] the profile’s display name
    # @param proxy_config    [Hash]   keys: :ip, :port, :user, :password, :proxy_soft (default 'other'), :proxy_type (default 'http')
    # @param group_id        [String] which AdsPower group to assign (default '0')
    # @param browser_version [String] Chrome version to use (must match Chromedriver), defaults to adspower_default_browser_version
    # @return String the new profile’s ID
    def create2(name:, proxy_config:, group_id: '0', browser_version: nil)
        browser_version ||= adspower_default_browser_version

        with_lock do
            url = "#{adspower_listener}:#{port}/api/v2/browser-profile/create"
            body = {
                'name'            => name,
                'group_id'        => group_id,
                'user_proxy_config' => {
                'proxy_soft'     => proxy_config[:proxy_soft]     || 'other',
                'proxy_type'     => proxy_config[:proxy_type]     || 'http',
                'proxy_host'     => proxy_config[:ip],
                'proxy_port'     => proxy_config[:port].to_s,
                'proxy_user'     => proxy_config[:user],
                'proxy_password' => proxy_config[:password]
                },
                'fingerprint_config' => {
                    # 1) Chrome kernel version → must match your Chromedriver
                    'browser_kernel_config' => {
                        'version' => browser_version,
                        'type'    => 'chrome'
                    },
                    # 2) Auto‐detect timezone (and locale) from proxy IP
                    'automatic_timezone' => '1',
                    'timezone'           => '',
                    'language'           => [],
                    # 3) Force desktop UA (no mobile): empty random_ua & default UA settings
                    'ua' => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "\
"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/#{browser_version}.0.0.0 Safari/537.36",
                    'ua_category' => 'desktop',
                    #'screen_resolution' => '1920*1080',
                    'is_mobile' => false,
                    # standard desktop fingerprints
                    'webrtc'  => 'disabled',  # hide real IP via WebRTC
                    'flash'   => 'allow',
                    'fonts'   => [],          # default fonts
                }
            }

            res = BlackStack::Netting.call_post(url, body)
            ret = JSON.parse(res.body)
            raise "Error creating profile: #{ret['msg']}" unless ret['code'] == 0

            ret['data']['profile_id']
        end
    end # def create2
    
    # Delete a user profile via API call.
    def delete(id)
        with_lock do
            url = "#{self.adspower_listener}:#{port}/api/v1/user/delete"
            body = {
                'api_key' => self.key,
                'user_ids' => [id],
            }
            # API call
            res = BlackStack::Netting.call_post(url, body)
            ret = JSON.parse(res.body)
            raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        end
    end

    # Start the browser with the given user profile and return the connection details.
    def start(id, headless=false)
        with_lock do
            url = "#{self.adspower_listener}:#{port}/api/v1/browser/start?user_id=#{id}&headless=#{headless ? '1' : '0'}"
            uri = URI.parse(url)
            res = Net::HTTP.get(uri)
            ret = JSON.parse(res)
            raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
            ret
        end
    end

    # Stop the browser session for the given user profile.
    def stop(id)
        with_lock do
            if @@drivers[id] && self.check(id)
                @@drivers[id].quit
                @@drivers[id] = nil
            end

            uri = URI.parse("#{self.adspower_listener}:#{port}/api/v1/browser/stop?user_id=#{id}")
            res = Net::HTTP.get(uri)
            ret = JSON.parse(res)
            raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
            ret
        end
    end

    # Check if the browser session for the given user profile is active.
    def check(id)
        with_lock do
            url = "#{self.adspower_listener}:#{port}/api/v1/browser/active?user_id=#{id}"
            uri = URI.parse(url)
            res = Net::HTTP.get(uri)
            return false if JSON.parse(res)['msg'] != 'success'
            JSON.parse(res)['data']['status'] == 'Active'
        end
    end

    # Attach to the existing browser session with Selenium WebDriver.
    def driver(id, headless=false)
        # Return the existing driver if it's still active.
        old = @@drivers[id]
        return old if old

        # Otherwise, start the driver
        ret = self.start(id, headless)

        # Attach test execution to the existing browser
        url = ret['data']['ws']['selenium']
        opts = Selenium::WebDriver::Chrome::Options.new
        opts.add_option("debuggerAddress", url)

        # Connect to the existing browser
        driver = Selenium::WebDriver.for(:chrome, options: opts)

        # Save the driver
        @@drivers[id] = driver

        # Return the driver
        driver
    end

    # Attach to the existing browser session with Selenium WebDriver.
    def driver2(id, headless: false, read_timeout: 180)
        # Return the existing driver if it's still active.
        old = @@drivers[id]
        return old if old

        # Otherwise, start the driver
        ret = self.start(id, headless)

        # Attach test execution to the existing browser
        url = ret['data']['ws']['selenium']
        opts = Selenium::WebDriver::Chrome::Options.new
        opts.add_option("debuggerAddress", url)

        # Set up the custom HTTP client with a longer timeout
        client = Selenium::WebDriver::Remote::Http::Default.new
        client.read_timeout = read_timeout # Set this to the desired timeout in seconds

        # Connect to the existing browser
        driver = Selenium::WebDriver.for(:chrome, options: opts, http_client: client)

        # Save the driver
        @@drivers[id] = driver

        # Return the driver
        driver
    end

    # DEPRECATED - Use Zyte instead of this method.
    #
    # Create a new profile, start the browser, visit a page, grab the HTML, and clean up.
    def html(url)
        ret = {
            :profile_id => nil,
            :html => nil,
            :status => 'success',
        }
        id = nil
        html = nil
        begin
            # Create the profile
            sleep(1)
            id = self.create

            # Update the result
            ret[:profile_id] = id

            # Start the profile and attach the driver
            driver = self.driver(id)

            # Get HTML
            driver.get(url)
            html = driver.page_source

            # Update the result
            ret[:html] = html

            # Stop the profile
            sleep(1)
            driver.quit
            self.stop(id)

            # Delete the profile
            sleep(1)
            self.delete(id)

            # Reset ID
            id = nil
        rescue => e
            # Stop and delete current profile if an error occurs
            if id
                sleep(1)
                self.stop(id)
                sleep(1)
                driver.quit if driver
                self.delete(id) if id
            end
            # Inform the exception
            ret[:status] = e.to_s
#        # process interruption
#        rescue SignalException, SystemExit, Interrupt => e 
#            if id
#                sleep(1) # Avoid the "Too many request per second" error
#                self.stop(id)
#                sleep(1) # Avoid the "Too many request per second" error
#                driver.quit
#                self.delete(id) if id
#            end # if id
        end
        # Return
        ret
    end
end

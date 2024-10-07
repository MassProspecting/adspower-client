require 'uri'
require 'net/http'
require 'json'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'
require 'fileutils'

class AdsPowerClient    
    # reference: https://localapi-doc-en.adspower.com/
    # reference: https://localapi-doc-en.adspower.com/docs/Rdw7Iu
    attr_accessor :key, :port, :server_log, :adspower_listener, :adspower_default_browser_version

    # control over the drivers created, in order to not create the same driver twice and not generate memory leaks.
    # reference: https://github.com/leandrosardi/adspower-client/issues/4
    @@drivers = {}

    LOCK_FILE = '/tmp/adspower_api_lock'

    def initialize(h={})
        self.key = h[:key] # mandatory
        self.port = h[:port] || '50325'
        self.server_log = h[:server_log] || '~/adspower-client.log'
        self.adspower_listener = h[:adspower_listener] || 'http://127.0.0.1'
        self.adspower_default_browser_version = h[:adspower_default_browser_version] || '116'
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
    end

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

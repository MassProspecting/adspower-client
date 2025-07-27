require 'uri'
require 'net/http'
require 'json'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'
require 'fileutils'
require 'countries'

class AdsPowerClient  
    CLOUD_API_BASE = 'https://api.adspower.com/v1'

    # Constante generada en tiempo de ejecución:
    COUNTRY_LANG = ISO3166::Country.all.each_with_object({}) do |country, h|
        # El primer idioma oficial (ISO 639-1) que encuentre:
        language_code = country.languages&.first || 'en'
        # Construimos la etiqueta BCP47 Language-Region:
        h[country.alpha2] = "#{language_code}-#{country.alpha2}"
    end.freeze

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


    # Lookup GeoIP gratuito (freegeoip.app) y parseo básico
    def geolocate(ip)
        uri = URI("https://freegeoip.app/json/#{ip}")
        res = Net::HTTP.get(uri)
        h = JSON.parse(res)
        {
        country_code: h["country_code"],
        time_zone:    h["time_zone"],
        latitude:     h["latitude"],
        longitude:    h["longitude"]
        }
    rescue
        # Fallback genérico
        { country_code: "US", time_zone: "America/New_York", latitude: 38.9, longitude: -77.0 }
    end

    # Create a new desktop profile with:
    #  • name, proxy, fingerprint, etc (unchanged)
    #  • platform (e.g. "linkedin.com")
    #  • tabs     (Array of URLs to open)
    #  • username / password / fakey for that platform
    #
    # @param name            [String] the profile’s display name
    # @param proxy_config    [Hash]   keys: :ip, :port, :user, :password, :proxy_soft (default 'other'), :proxy_type (default 'http')
    # @param group_id        [String] which AdsPower group to assign (default '0')
    # @param browser_version [String] optional Chrome version to use (must match Chromedriver). Only applies if `fingerprint` is nil, as custom fingerprints override kernel settings.
    # @param os              [String] target OS for Chrome binary (one of 'linux64', 'mac-x64', 'mac-arm64', 'win32', 'win64'; default 'linux64'); used to filter the known-good versions JSON so we pick a build that actually ships for that platform
    # @param fingerprint     [Hash, nil] optional fingerprint configuration. If not provided, a stealth-ready default is applied with DNS-over-HTTPS, spoofed WebGL/Canvas/audio, consistent User-Agent and locale, and hardening flags to minimize detection risks from tools like BrowserScan, Cloudflare, and Arkose Labs.
    # @param platform        [String] (optional) target site domain, e.g. 'linkedin.com'
    # @param tabs            [Array<String>] (optional) array of URLs to open on launch
    # @param username        [String] (optional) platform login username
    # @param password        [String] (optional) platform login password
    # @param fakey           [String,nil] optional 2FA key
    # @return String the new profile’s ID
    def create2(
        name:, 
        proxy_config:, 
        group_id: '0', 
        browser_version: nil,
        os:              'linux64',# new: one of linux64, mac-x64, mac-arm64, win32, win64
        fingerprint:     nil,
        platform:        '',       # default: no platform
        tabs:            [],       # default: no tabs to open
        username:        '',       # default: no login
        password:        '',       # default: no password
        fakey:           ''        # leave blank if no 2FA
    )
        browser_version ||= adspower_default_browser_version
        
        # 0) Resolve full Chrome version ─────────────────────────────
        # Fetch the list of known-good Chrome versions and pick the highest
        uri = URI('https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json')
        resp = Net::HTTP.get_response(uri)
        unless resp.is_a?(Net::HTTPSuccess)
            raise "Error fetching Chrome versions: HTTP #{resp.code}"
        end
        listing = JSON.parse(resp.body)
        entries = listing['versions'] || []
        # keep only those entries whose version matches prefix *and* has a download for our OS
        matches = entries.
          select { |e|
            e['version'].start_with?("#{browser_version}.") &&
            e.dig('downloads','chrome').any? { |d| d['platform'] == os }
          }.
          map { |e| e['version'] }
        if matches.empty?
            raise "Chrome version '#{browser_version}' not found in known-good versions list"
        end
        # pick the highest patch/build by semantic compare
        full_version = matches
            .map { |ver| ver.split('.').map(&:to_i) }
            .max
            .join('.')

        # 1) Hacemos GeoIP sobre la IP del proxy
        geo = geolocate(proxy_config[:ip])
        lang = COUNTRY_LANG[geo[:country_code]] || "en-US"
        screen_res = "1920_1080"

        with_lock do
            url = "#{adspower_listener}:#{port}/api/v2/browser-profile/create"
            body = {
                # ─── GENERAL & PROXY ─────────────────────────────
                'name'            => name,
                'group_id'        => group_id,
                'user_proxy_config' => {
                    'proxy_soft'     => proxy_config[:proxy_soft]     || 'other',
                    'proxy_type'     => proxy_config[:proxy_type]     || 'socks5',
                    'proxy_host'     => proxy_config[:ip],
                    'proxy_port'     => proxy_config[:port].to_s,
                    'proxy_user'     => proxy_config[:user],
                    'proxy_password' => proxy_config[:password],

                    # ─── FORCE ALL DNS THROUGH PROXY ─────────────────
                    # Avoid DNS-Leak
                    "proxy_dns":        1,                           # 1 = yes, 0 = no
                    "dns_servers":     ["8.8.8.8","8.8.4.4"]         # optional: your choice of DNS
                },

                # ─── PLATFORM ─────────────────────────────────────
                'platform'          => platform,  # must be one of AdsPower’s supported “sites”
                'tabs'              => tabs,      # array of URLs to open
                'username'          => username,
                'password'          => password,
                'fakey'             => fakey,     # 2FA, if any

                # ─── FINGERPRINT ──────────────────────────────────
                "fingerprint_config" => fingerprint || {

                    # ─── 0) DNS Leak Prevention ───────────────────────────
                    # Even with “proxy_dns” forced on, a few ISPs will still 
                    # silently intercept every UDP:53 out of your AdsPower VPS 
                    # and shove it into their own resolver farm (the classic 
                    # “transparent DNS proxy” attack that BrowserScan is warning you about). 
                    #
                    # Because you refuse to hot-patch your Chrome via extra args or CDP, 
                    # the only way to survive an ISP-level hijack is to push all name lookups 
                    # into an encrypted channel that the ISP simply can’t touch: DNS-over-HTTPS (DoH).
                    #
                    # Here’s the minimal change you need to bake into your AdsPower profile at 
                    # creation time so that every DNS query happens inside Chrome’s DoH stack:
                    # 
                    "extra_launch_flags" => [
                        # === DNS over HTTPS only ===
                        "--enable-features=DnsOverHttps",
                        "--dns-over-https-mode=secure",
                        "--dns-over-https-templates=https://cloudflare-dns.com/dns-query",
                        "--disable-ipv6",

                        # === hide “Chrome is being controlled…” banner ===
                        #
                        # Even though you baked in the DoH flags under extra_launch_flags, 
                        # you never told Chrome to hide its “automation” banners or black-hole 
                        # all other DNS lookups — and BrowserScan still sees those UDP:53 calls 
                        # leaking out.
                        # 
                        # What you need is to push three more flags into your profile creation, 
                        # and then attach with the exact same flags when Selenium hooks in.
                        # 
                        "--disable-blink-features=AutomationControlled",
                        "--disable-infobars",
                        "--disable-features=TranslateUI",            # optional but reduces tell-tale infobars
                        "--host-resolver-rules=MAP * 0.0.0.0,EXCLUDE localhost,EXCLUDE cloudflare-dns.com"
                    ],

                    # ─── 1) Kernel & versión ───────────────────────────
                    "browser_kernel_config" => {
                        "version" => browser_version,   # aquí usamos el parámetro
                        "type"    => "chrome"
                    },

                    # ─── 2) Timezone & locale ──────────────────────────
                    "automatic_timezone" => "1",
                    #"timezone"           => geo[:time_zone],
                    "language"           => [ lang ],

                    # ─── 3) User-Agent coherente ───────────────────────
                    "ua_category" => "desktop",
                    'ua' => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/#{full_version} Safari/537.36",
                    "is_mobile"   => false,

                    # ─── 4) Pantalla y plataforma ──────────────────────
                    # It turns out that “Based on User-Agent” is purely a UI setting
                    #"screen_resolution" => screen_res, "1920_1080"
                    "platform"          => "Linux x86_64",

                    # ─── 5) Canvas & WebGL custom ─────────────────────
                    "canvas"        => "1",
                    "webgl_image"   => "1",
                    "webgl"         => "0",    # 0=deshabilitado, 2=modo custom, 3=modo random-match
                    "webgl_config"  => {
                        "unmasked_vendor"   => "Intel Inc.",
                        "unmasked_renderer" => "ANGLE (Intel, Mesa Intel(R) Xe Graphics (TGL GT2), OpenGL 4.6)",
                        "webgpu"            => { "webgpu_switch" => "1" }
                    },

                    # ─── 6) Resto de ajustes ───────────────────────────
                    "webrtc"   => "disabled",   # WebRTC sí admite “disabled”
                    "flash"    => "block",      # Flash únicamente “allow” o “block”
                    "fonts"    => []            # usar fonts por defecto
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

    def driver2(id, headless: false, read_timeout: 180)
        return @@drivers[id] if @@drivers[id]
      
        # 1) start the AdsPower profile / grab its WebSocket URL
        data = start(id, headless)['data']
        ws   = data['ws']['selenium']  # e.g. "127.0.0.1:XXXXX"
      
        # 2) attach with DevTools (no more excludeSwitches or caps!)
        opts = Selenium::WebDriver::Chrome::Options.new
        opts.debugger_address = ws
        opts.add_argument('--headless') if headless
      
        http = Selenium::WebDriver::Remote::Http::Default.new
        http.read_timeout = read_timeout
      
        driver = Selenium::WebDriver.for(:chrome, options: opts, http_client: http)

        driver.execute_cdp(
            'Page.addScriptToEvaluateOnNewDocument',
            source: <<~JS
                // 1) remove any leftover cdc_… / webdriver hooks
                for (const k of Object.getOwnPropertyNames(window)) {
                if (k.startsWith('cdc_') || k.includes('webdriver')) {
                    try { delete window[k]; } catch(e){}
                }
                }

                // 2) stub out window.chrome so Chrome-based detection thinks this is “normal” Chrome
                window.chrome = { runtime: {} };
            JS
        )

        @@drivers[id] = driver
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

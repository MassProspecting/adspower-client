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

    # Create a new desktop profile with custom name, proxy, and fingerprint settings
    #
    # @param name            [String] the profile’s display name
    # @param proxy_config    [Hash]   keys: :ip, :port, :user, :password, :proxy_soft (default 'other'), :proxy_type (default 'http')
    # @param group_id        [String] which AdsPower group to assign (default '0')
    # @param browser_version [String] Chrome version to use (must match Chromedriver), defaults to adspower_default_browser_version
    # @return String the new profile’s ID
    def create2(name:, proxy_config:, group_id: '0', browser_version: nil)
        browser_version ||= adspower_default_browser_version

        # 1) Hacemos GeoIP sobre la IP del proxy
        geo = geolocate(proxy_config[:ip])
        lang = COUNTRY_LANG[geo[:country_code]] || "en-US"

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
                    # Desactivamos auto-timezone de AdsPower
                    "automatic_timezone" => "0",
                    # Forzamos la zona horaria del proxy
                    "timezone"           => geo[:time_zone],
                    # Idioma/locale coherente con país
                    "language"           => [ lang ],
                    # Coordenadas geográficas (si AdsPower las soporta)
                    "latitude"           => geo[:latitude].to_s,
                    "longitude"          => geo[:longitude].to_s,
                    # UA forzado a escritorio Windows/Mac/Linux según país
                    "ua_category"        => 'desktop',
                    "ua" => "Mozilla/5.0 (X11; Linux x86_64) "\
                            "AppleWebKit/537.36 (KHTML, like Gecko) "\
                            "Chrome/#{browser_version}.0.0.0 Safari/537.36",
                    # Hardware y plugins mínimos estándar
                    "is_mobile"  => false,
                    "webrtc"     => 'disabled',
                    "flash"      => 'allow',
                    "fonts"      => [],      # Dejar fonts por defecto
                    "screen_resolution" => '1920*1080'  # o puedes rotar por país
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

        # elimina el switch “enable-automation”
        opts.add_option(
            "excludeSwitches", ['enable-automation']
        )
        # desactiva la extensión de automatización
        opts.add_option(
            "useAutomationExtension", false
        )
        # quita la marca de “Blink Automation”
        opts.add_argument(
            "--disable-blink-features=AutomationControlled"
        )
        # si quieres headless
        opts.add_argument("--headless") if headless
  
        # Set up the custom HTTP client with a longer timeout
        client = Selenium::WebDriver::Remote::Http::Default.new
        client.read_timeout = read_timeout # Set this to the desired timeout in seconds

        # Connect to the existing browser
        driver = Selenium::WebDriver.for(:chrome, options: opts, http_client: client)

        # 4) Inyecta un script que redefina navigator.webdriver **antes** de que la página cargue
        driver.execute_cdp(
            'Page.addScriptToEvaluateOnNewDocument',
            source: <<~JS
            // sobreescribe por completo la propiedad webdriver
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined,
                configurable: true
            });
            JS
        )
=begin
        # ------------- AQUI VA LA INYECCIÓN MÁGICA -------------
        driver.execute_cdp(
            'Page.addScriptToEvaluateOnNewDocument',
            source: <<~JS
            // 1) navigator.webdriver
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined,
                configurable: true
            });

            // 2) User-Agent versión alineada a Chrome 136
            const ua = "Mozilla/5.0 (X11; Linux x86_64) "\
        "(KHTML, like Gecko) Chrome/136.0.7103.59 Safari/537.36";
            Object.defineProperty(navigator, 'userAgent', { get: () => ua });
            Object.defineProperty(navigator, 'appVersion',{ get: () => ua });

            // 3) platform, oscpu
            Object.defineProperty(navigator, 'platform', { get: () => 'Linux x86_64' });
            Object.defineProperty(navigator, 'oscpu',    { get: () => 'Linux x86_64' });

            // 4) languages
            Object.defineProperty(navigator, 'language',  { get: () => 'en-US' });
            Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });

            // 5) Webdriver vendor / renderer leaks (WebGL & AudioContext)
            const getParameter = WebGLRenderingContext.prototype.getParameter;
            WebGLRenderingContext.prototype.getParameter = function(parameter) {
                // por ejemplo, parchea los vendor strings:
                if (parameter === 37445) return 'Intel Inc.';    // VENDOR
                if (parameter === 37446) return 'Intel Iris';    // RENDERER
                return getParameter(parameter);
            };

            const AudioContext = window.AudioContext;
            window.AudioContext = function() {
                const ctx = new AudioContext();
                // parchea un pequeño ruido en la fingerprint:
                const orig = ctx.createAnalyser;
                ctx.createAnalyser = function() {
                const analyser = orig.call(this);
                analyser.getFloatFrequencyData = function(arr) {
                    // inyecta micro-ruido:
                    for (let i = 0; i < arr.length; i++) {
                    arr[i] += (Math.random() - 0.5) * 1e-5;
                    }
                    return arr;
                };
                return analyser;
                };
                return ctx;
            };

            // 6) Emulación de timezone e idioma en CDP
            JS
        )

        # Finalmente, fuerza el timezone a America/New_York
        driver.execute_cdp('Emulation.setTimezoneOverride', timezoneId: 'America/New_York')

        # Si quieres, ajusta aquí también viewport/resolución, por ejemplo:
        driver.execute_cdp('Emulation.setDeviceMetricsOverride', {
            width: 1920, height: 1080, deviceScaleFactor: 1,
            mobile: false
        })
=end
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

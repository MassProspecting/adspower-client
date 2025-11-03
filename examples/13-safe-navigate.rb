require_relative '../config.rb'
require_relative '../lib/adspower-client.rb'
require 'colorize'
require 'pry'

# profile id
pid = 'k10818n3'
url = 'https://google.com'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
client.server_start
puts client.online? ? 'yes'.green : 'no'.red

# open the browser
driver = client.driver2(pid, 
    headless: false
)

binding.pry

=begin
Sometimes, the line below `driver.get('https://google.com')` raises one of the following exceptions:
1. `Errno::ECONNREFUSED: Failed to open TCP connection to 127.0.0.1:9515 (Connection refused - connect(2) for 127.0.0.1:9515)`
2. `invalid session id`
3. `no such window: target window already closed`

Considering the source code of `adspower-client.rb` (the library used in this example),
add proper error catching to the line `driver.get('https://google.com')` in order to
handle these errors properly and - if it is neccessary - restart the browser.

Example:

1. The exception `Errno::ECONNREFUSED: Failed to open TCP...` is raised if I do `driver.quit` before `driver.get('https://google.com')`
2. The exception `no such window: target window already closed` is raised if I close the browser manually before `driver.get('https://google.com')`
3. The exception `Invalid session id` is raised if I do `driver.quit` before `driver.get('https://google.com')`
=end

begin
    driver.get(url)
rescue  Errno::ECONNREFUSED, 
        Selenium::WebDriver::Error::InvalidSessionIdError,
        Selenium::WebDriver::Error::NoSuchWindowError, 
        Selenium::WebDriver::Error::WebDriverError => e

    warn "navigation error (#{e.class}): #{e.message}"

    # 1) first try: ask AdsPower agent to stop the remote browser (preferred)
    begin
        client.stop(pid)
    rescue => stop_err
        warn "client.stop failed: #{stop_err.class}: #{stop_err.message}"
        # 2) fallback: best-effort local cleanup of cached driver object
        AdsPowerClient.cleanup(pid)
    end

    # 3) small pause to let ports/sockets free
    sleep 1

    # 4) re-create / re-attach a driver and retry navigation once
    driver = client.driver2(pid, headless: false)
    driver.get(url)
rescue => final_err
    warn "final navigation failed: #{final_err.class}: #{final_err.message}"
end

require 'uri'
require 'net/http'
require 'json'
require 'pry'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'

class AdsPowerClient    
    # reference: https://localapi-doc-en.adspower.com/
    # reference: https://localapi-doc-en.adspower.com/docs/Rdw7Iu
    attr_accessor :key, :adspower_listener, :adspower_default_browser_version

    def initialize(h)
        self.key = h[:key] # mandatory
        self.adspower_listener = h[:adspower_listener] || 'http://127.0.0.1:50325'
        self.adspower_default_browser_version = h[:adspower_default_browser_version] || '116'
    end

    # send an GET request to "#{url}/status"
    # and return the response body.
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/6DSiws
    # 
    def status
        url = "#{self.adspower_listener}/status"
        uri = URI.parse(url)
        res = Net::HTTP.get(uri)
        # show respose body
        return JSON.parse(res)['msg']
    end

    # send a post request to "#{url}/api/v1/user/create"
    # and return the response body.
    #
    # return id of the created user
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/6DSiws
    # reference: https://localapi-doc-en.adspower.com/docs/Lb8pOg
    # reference: https://localapi-doc-en.adspower.com/docs/Awy6Dg
    # 
    def create
        url = "#{self.adspower_listener}/api/v1/user/create"
        body = {
            #'api_key' => self.key,
            'group_id' => '0',
            'proxyid' => '1',
            'fingerprint_config' => {
                'browser_kernel_config' => {"version": self.adspower_default_browser_version, "type":"chrome"}
            }
        }
        # api call
        res = BlackStack::Netting.call_post(url, body)
        # show respose body
        ret = JSON.parse(res.body)
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        # return id of the created user
        ret['data']['id']
    end

    def delete(id)
        url = "#{self.adspower_listener}/api/v1/user/delete"
        body = {
            'api_key' => self.key,
            'user_ids' => [id],
        }
        # api call
        res = BlackStack::Netting.call_post(url, body)
        # show respose body
        ret = JSON.parse(res.body)
        # validation
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
    end

    # run the browser
    # return the URL to operate the browser thru selenium
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/FFMFMf
    # 
    def start(id)
        uri = URI.parse("#{self.adspower_listener}/api/v1/browser/start?user_id=#{id}")
        res = Net::HTTP.get(uri)
        # show respose body
        ret = JSON.parse(res)
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        # return id of the created user
        ret
    end
end # class AdsPowerClient

client = AdsPowerClient.new(
    key: '*********',
)

#p client.status
# => "success"

#p client.create
# => "jc8y0yt"

#client.delete('jc8y0yt')

id = client.create
p client.start(id)
# => ""

=begin
# Attach test execution to the existing browser
# reference: https://zhiminzhan.medium.com/my-innovative-solution-to-test-automation-attach-test-execution-to-the-existing-browser-b90cda3b7d4a
url = ret['data']['ws']['selenium']
opts = Selenium::WebDriver::Chrome::Options.new
opts.add_option("debuggerAddress", url)

# connect to the existing browser
# reference: https://localapi-doc-en.adspower.com/docs/K4IsTq
driver = Selenium::WebDriver.for(:chrome, :options=>opts)

driver.get 'https://google.com'
=end
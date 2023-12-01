require 'uri'
require 'net/http'
require 'json'
require 'pry'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'

# reference: https://localapi-doc-en.adspower.com/
# reference: https://localapi-doc-en.adspower.com/docs/Rdw7Iu
@key = 'b729c93ea23eea308bdeb07c8d2a49a8'
@url = 'http://127.0.0.1:50325'

# send an GET request to "#{url}/status"
# and return the response body.
# 
# reference: https://localapi-doc-en.adspower.com/docs/6DSiws
# 
def status
    uri = URI.parse("#{@url}/status")
    res = Net::HTTP.get(uri)
    # show respose body
    puts JSON.parse(res)['msg']
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
    url = "#{@url}/api/v1/user/create"
    body = {
        #'api_key' => @key,
        'group_id' => '0',
        'proxyid' => '1',
        'fingerprint_config' => {
            'browser_kernel_config' => {"version": "115", "type":"chrome"}
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
    url = "#{@url}/api/v1/user/delete"
    body = {
        'api_key' => @key,
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
    uri = URI.parse("#{@url}/api/v1/browser/start?user_id=#{id}")
    res = Net::HTTP.get(uri)
    # show respose body
    ret = JSON.parse(res)
    raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
    # return id of the created user
    ret
end

id = create()
puts id

#delete('jc5fiad')
=begin
ret = start('jc5gajl')

url = ret['data']['ws']['selenium']
opts = Selenium::WebDriver::Chrome::Options.new
opts.add_option("debuggerAddress", url)

# connect to the existing browser
# reference: https://localapi-doc-en.adspower.com/docs/K4IsTq
driver = Selenium::WebDriver.for(:chrome, :options=>opts)

driver.get 'https://google.com'
=end
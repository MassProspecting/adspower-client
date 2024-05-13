# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'adspower-client'
require 'pry'

ADSPOWER_API_KEY = '0d92ca77432a5ecc49464ea92d779def'
PROFILE_ID = 'jhshn1p'

client = AdsPowerClient.new(key: ADSPOWER_API_KEY)

# open the browser
driver = client.driver(PROFILE_ID)

# show the number of `chromedriver` processes running
puts `ps aux | grep "chromedriver"`

# breakpoint for you, to experiment starting and closseing drivers
binding.pry

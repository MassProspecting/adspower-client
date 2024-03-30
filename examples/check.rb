# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'adspower-client'
require 'pry'

ADSPOWER_API_KEY = 'd21e62f903efff0cb309f96342b35029'
PROFILE_ID = 'jg2e5ck'

client = AdsPowerClient.new(key: ADSPOWER_API_KEY)

# open the browser
driver = client.driver(PROFILE_ID)

# show the number of `chromedriver` processes running
puts `ps aux | grep "chromedriver"`

# breakpoint for you, to experiment starting and closseing drivers
binding.pry

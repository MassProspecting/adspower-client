# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

#require 'adspower-client'
require_relative '../lib/adspower-client'
require 'pry'

ADSPOWER_API_KEY = '00db0bb239d8c95acbfdf03ab8eb1414'
PROFILE_ID = 'jdus77h'

client = AdsPowerClient.new(key: ADSPOWER_API_KEY)

# open the browser
driver = client.driver(PROFILE_ID)

# show the number of `chromedriver` processes running
puts `ps aux | grep "chromedriver"`

# breakpoint for you, to experiment starting and closseing drivers
binding.pry

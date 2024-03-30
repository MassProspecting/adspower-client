# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

#require 'adspower-client'
require_relative '../lib/adspower-client'

require 'pry'

ADSPOWER_API_KEY = 'd21e62f903efff0cb309f96342b35029'
ADSPOWER_PORT = '50325'

PROFILE_ID = 'jg2e5ck'
HEADLESS = false

# create an adspower client
client = AdsPowerClient.new(key: ADSPOWER_API_KEY, port: ADSPOWER_PORT)

# start the server
client.server_start if client.server_running? == false

# open the browser
driver = client.driver(PROFILE_ID, HEADLESS)

# show the number of `chromedriver` processes running
puts `ps aux | grep "chromedriver"`

# visit google.com
driver.get('https://google.com')
puts driver.title

# visit to https://mercadolibre.com
#driver.get('https://mercadolibre.com')
#puts driver.title

# maximize window
driver.manage.window.maximize

# take screenshot
driver.save_screenshot("/tmp/screenshot3.png")

# close the browser
driver.quit

# stop the server
client.server_stop
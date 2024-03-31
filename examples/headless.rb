# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'pry'
require 'my-dropbox-api'

#require 'adspower-client'
require_relative '../lib/adspower-client'
require_relative './config'

#
filename = "screenshot4.png"

# create an adspower client
client = AdsPowerClient.new(key: ADSPOWER_API_KEY, port: ADSPOWER_PORT)

# start the server
client.server_start if client.online? == false

# open the browser
driver = client.driver(PROFILE_ID, HEADLESS)

# show the number of `chromedriver` processes running
puts `ps aux | grep "chromedriver"`

# visit google.com
driver.get('https://google.com')
puts driver.title

# visit to https://mercadolibre.com
driver.get('https://mercadolibre.com')
puts driver.title

# maximize window
driver.manage.window.maximize

# take screenshot
driver.save_screenshot("/tmp/#{filename}")

# upload screenshot to dropbox
BlackStack::DropBox.dropbox_upload_file("/tmp/#{filename}", "/#{filename}")

# close the browser
driver.quit

# stop the server
client.server_stop
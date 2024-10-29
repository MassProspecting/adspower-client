# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'pry'
require 'my-dropbox-api'

#require 'adspower-client'
require_relative '../lib/adspower-client'
require_relative './config'

# create an adspower client
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY, 
    port: ADSPOWER_PORT,
    server_log: '~/foo.log',
)

# open the browser
driver = client.driver2(PROFILE_ID, 
    headless: HEADLESS,
    read_timeout: 200
)


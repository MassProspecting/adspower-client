# Avoid memory leaks.
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
#
# Manage headless mode.
# Reference: https://github.com/MassProspecting/adspower-client/issues/2
#

require 'adspower-client'
#require_relative '../lib/adspower-client'

# The following constants are defined in this file of secrets:
# ADSPOWER_API_KEY
# ADSPOWER_PORT
# PROFILE_ID
# HEADLESS
require_relative './config'

# create an adspower client
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY, 
    port: ADSPOWER_PORT,
    server_log: '~/foo.log',
)

# start the server
client.server_start if client.online? == false

# open the browser
driver = client.driver(PROFILE_ID, HEADLESS)

# visit google.com
driver.get('https://google.com')
puts driver.title
# => Google

# visit to https://mercadolibre.com
driver.get('https://mercadolibre.com')
puts driver.title
# => Mercado Libre - Envíos Gratis en el día

# close the browser
driver.quit

# stop the server
client.server_stop
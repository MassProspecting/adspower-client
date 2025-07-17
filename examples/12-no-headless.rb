require_relative '../config.rb'
require_relative '../lib/adspower-client.rb'
require 'pry'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)

client.server_start
puts client.online? ? 'yes' : 'no'

# open the browser
driver = client.driver2('k11vhkyy', 
    headless: false
)


require_relative '../config.rb'
require_relative '../lib/adspower-client.rb'
require 'pry'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
puts client.online? ? 'yes' : 'no'
# => Is AdsPower running?... yes

driver = client.driver('k11vf5at')

driver.get('https://google.com')

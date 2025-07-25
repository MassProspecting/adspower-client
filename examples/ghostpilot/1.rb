require_relative '../../config.rb'
require_relative '../../lib/adspower-client.rb'
require 'pry'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
puts client.online? ? 'yes' : 'no'
# => Is AdsPower running?... yes

print 'Starting profile... '
ret = client.start('k1206s7v')
puts ret

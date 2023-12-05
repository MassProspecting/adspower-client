#require_relative '../lib/adspower-client'
require 'adspower-client'

client = AdsPowerClient.new
puts client.html('http://foo.com')


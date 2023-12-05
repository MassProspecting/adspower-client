require_relative '../lib/adspower'

client = AdsPowerClient.new
puts client.html('http://foo.com')


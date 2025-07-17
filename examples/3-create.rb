require_relative '../config.rb'
require_relative '../lib/adspower-client.rb'
require 'pry'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
puts client.online? ? 'yes' : 'no'
# => Is AdsPower running?... yes

print 'Creating profile... '
profile_id = client.create(
    name:               'Example Profile',
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'http',
        ip:             '207.228.20.71',
        port:           49656,
        user:           'RnjcnnEKQEXplKn',
        password:       'ciQKegU75q0aXw7'
    },
    group_id:           '0',
    browser_version:    '131'
)
puts "done! Profile ID: #{profile_id}"
# => Creating profile... done! Profile ID: k11vcxmw

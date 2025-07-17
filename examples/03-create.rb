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
profile_id = client.create2(
    name:               'Example Profile',
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'http',
        ip:             '55.55.55.55',
        port:           49656,
        user:           '***************',
        password:       '***************'
    },
    group_id:           '0',
    browser_version:    '131'
)
puts "done! Profile ID: #{profile_id}"
# => Creating profile... done! Profile ID: k11vcxmw

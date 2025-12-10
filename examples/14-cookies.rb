require_relative '../config.rb'
require_relative '../lib/adspower-client.rb'
require 'colorize'
require 'pry'

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
    name:               'Example Profile 03',
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'http',
        ip:             '178.94.165.130',
        port:           42557,
        user:           'mzpVWET3hTxes64',
        password:       'cfdCP9HycrU2QZ1'
    },
    group_id:           '0',
    browser_version:    '131',
    os:                 'win32',
    cookie:             File.read('/home/leandro/Desktop/leandro-sardi.json')
)
puts "done! Profile ID: #{profile_id}"
# => Creating profile... done! Profile ID: k11vcxmw

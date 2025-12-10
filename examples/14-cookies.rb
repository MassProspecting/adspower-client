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
    proxy_config:       PROXY,
    group_id:           '0',
    browser_version:    '131',
    os:                 'linux64',

    platform:           'linkedin.com', 
    tabs:               ['https://www.linkedin.com/feed'],
    username:           EMAIL, 
    password:           PASSW, 

    cookie:             File.read('/home/leandro/Desktop/leandro-sardi.json')
)
puts "done! Profile ID: #{profile_id}"
# => Creating profile... done! Profile ID: k11vcxmw

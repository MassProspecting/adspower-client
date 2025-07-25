require_relative '../../config.rb'
require_relative '../../lib/adspower-client.rb'
require 'pry'
require 'colorize'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
puts client.online? ? 'yes' : 'no'
# => Is AdsPower running?... yes

timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
print "Creating profile #{timestamp.blue}... "
profile_id = client.create2(
    name:               "Synthetic - #{timestamp}",
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'socks5',
        ip:             PROXY[:ip],
        port:           PROXY[:port],
        user:           PROXY[:username],
        password:       PROXY[:password]
    },
    group_id:           '0',
    browser_version:    '131' # Make sure your AdsPower profile’s browser_version matches 
                              # the actual Chrome Browser and ChromeDriver on disk.
)
puts "#{'done!'.green} Profile ID: #{profile_id.blue}"
# => Creating profile... done! Profile ID: k11vcxmw

print 'Starting profile... '
br = client.driver2(profile_id)
puts 'done!'.green

print 'Visiting BrowserScan... '
br.get('https://www.browserscan.net/')
puts 'done!'.green

binding.pry
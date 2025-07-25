require_relative '../../config.rb'
require_relative '../../lib/adspower-client.rb'
require 'pry'
require 'colorize'

profile_id = 'k12aubvj'

print 'Is AdsPower running?... '
client = AdsPowerClient.new(
    key: ADSPOWER_API_KEY
)
puts client.online? ? 'yes'.green : 'no'.red
# => Is AdsPower running?... yes

print 'Starting profile... '
br = client.driver2(profile_id)
puts 'done!'.green

print 'Visiting BrowserScan... '
#binding.pry
br.get('https://www.browserscan.net')
#br.execute_cdp('Page.navigate', url: 'https://www.browserscan.net/')
puts 'done!'.green
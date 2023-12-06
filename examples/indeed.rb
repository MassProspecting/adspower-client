require_relative '../lib/adspower-client'
#require 'adspower-client'
require 'simple_cloud_logging'
require 'colorize'
require_relative './aux/indeed-urls'

c = AdsPowerClient.new
l = BlackStack::LocalLogger.new('indeed.log')

l.log "Scraping Indeed Example".yellow

URLS.each { |url|
    l.logs "Scraping #{url[:name].blue}... "
    ret = c.html(url[:url])
    if ret[:status] == 'success'
        # write html into a file
        File.open("indeed-#{url[:name]}.html", 'w') { |f| f.write(ret[:html]) }
    end
    l.logf ret[:status] == 'success' ? 'done'.green : ret[:status].red
}

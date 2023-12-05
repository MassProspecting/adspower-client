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
    html = c.html(url[:url])
    l.logf 'done'.green
}

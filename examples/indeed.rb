require_relative '../lib/adspower-client'

client = AdsPowerClient.new
puts client.html('https://www.indeed.com/jobs?q=%2435%2C000&l=Jacksonville%2C+FL&radius=25&vjk=4d50a7da37ac13e8?start=60')


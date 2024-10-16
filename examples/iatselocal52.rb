# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'csv'
require 'adspower-client'
require 'nokogiri'
require 'pry'

ADSPOWER_API_KEY = '0d92ca77432a5ecc49464ea92d779def'
PROFILE_ID = 'koakxh2'
URL = 'https://www.iatselocal52.org/?zone=/unionactive/member_direc.cfm&action=search'

client = AdsPowerClient.new(key: ADSPOWER_API_KEY)

# open the browser
driver = client.driver(PROFILE_ID)

c = 'A'
url = "#{URL}&keyphrase=#{c}"
driver.get(url)
rows = driver.find_elements(css: 'table.darkfont tr')

i = 1 # 0 is the table header
while i < rows.size
    row = rows[i]
    td = row.find_element(css: 'td:first-child')
    div = td.find_element(css: 'div')
    onclick_code = div.attribute('onclick').to_s #.gsub(/return false;$/, '')
    code = onclick_code.match(/showgrievdialog\('(\d+)'\)/)[1]

    html = driver.execute_async_script("
        var callback = arguments[arguments.length - 1]; // This is the callback provided by Selenium to signal completion
        var xhrArgs = {
        url: 'index_blank.cfm?zone=show_user.cfm&thisuser=#{code}',
        handleAs: 'text',
        load: function(data) {
            dijit.byId('grievwindow').attr('content', data);
            dojo.destroy('loadingdiver');
            callback(data);  // Pass the data to the Selenium callback to indicate that the script is done
        },
        error: function(err) {
            callback(err);  // In case of an error, pass the error to the callback
        }
        };
        dojo.xhrPost(xhrArgs);
    ")
    
    # Parse the HTML
    doc = Nokogiri::HTML(html)
    
    # Extract the information into a hash
    info = {}
    info[:name] = doc.at('td[bgcolor]').text.strip
    info[:department] = doc.at('td:contains("Departmant:")').text.split(':').last.strip
    info[:address] = doc.at('td:contains("Address:")').text.gsub(/Address:/, '').strip
    info[:phone] = doc.at('td:contains("Phone:")').at('a').text.strip
    info[:phone_2] = doc.at('td:contains("Phone 2:")').at('a').text.strip
    info[:phone_3] = doc.at('td:contains("Phone 3:")').at('a').text.strip
    info[:email] = doc.at('td:contains("Email:")').text.split(':').last.strip
    info[:emergency_contact] = doc.at('td:contains("Emergency Contact:")').text.split(':').last.strip
    info[:emergency_phone] = doc.at('td:contains("Emergency Phone:")').text.split(':').last.strip
    
    # CSV
    # Write the extracted information into a CSV file
    CSV.open("iatselocal52.#{c}.csv", "w") do |csv|
        # Add header row
        csv << ["Name", "Department", "Address", "Phone", "Phone 2", "Phone 3", "Email", "Emergency Contact", "Emergency Phone"]
    
        # Add data row
        csv << [info[:name], info[:department], info[:address], info[:phone], info[:phone_2], info[:phone_3], info[:email], info[:emergency_contact], info[:emergency_phone]]
    end

    # next row
    i += 1
end
  
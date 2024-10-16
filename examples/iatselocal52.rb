# Avoid memory leaks.
#
# Reference: https://github.com/leandrosardi/adspower-client/issues/4
# 

require 'simple_cloud_logging'
require 'csv'
require 'adspower-client'
require 'nokogiri'
require 'pry'

ADSPOWER_API_KEY = '0d92ca77432a5ecc49464ea92d779def'
PROFILE_ID = 'koakxh2'
URL = 'https://www.iatselocal52.org/?zone=/unionactive/member_direc.cfm&action=search'

client = AdsPowerClient.new(key: ADSPOWER_API_KEY)
l = BlackStack::LocalLogger.new('iatselocal52.log')

# open the browser
driver = client.driver(PROFILE_ID)

('A'..'Z').each do |c|
    # 
    #c = 'A'

    # CSV
    # Initialization
    CSV.open("iatselocal52.#{c}.csv", "w") do |csv|
        # Add header row
        csv << ["First Name", "Last Name", "Name", "Department", "Address", "Phone", "Phone 2", "Phone 3", "Email", "Emergency Contact", "Emergency Phone"]
    end

    # iterate rows
    url = "#{URL}&keyphrase=#{c}"
    driver.get(url)
    rows = driver.find_elements(css: 'table.darkfont tr')
    i = 1 # 0 is the table header
    while i < rows.size
        l.logs "Row #{c.blue}.#{i.to_s.blue}... "

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
        info[:name] = doc.at('td[bgcolor]')&.text&.strip
        info[:first_name] = info[:name].split(', ').last if info[:name]
        info[:last_name] = info[:name].split(', ').first if info[:name]
        info[:department] = doc.at('td:contains("Departmant:")')&.text&.split(':')&.last&.strip
        info[:address] = doc.at('td:contains("Address:")')&.text&.gsub(/Address:/, '')&.strip
        info[:email] = doc.at('td:contains("Email:")')&.text&.split(':')&.last&.strip
        info[:emergency_contact] = doc.at('td:contains("Emergency Contact:")')&.text&.split(':')&.last&.strip
        info[:emergency_phone] = doc.at('td:contains("Emergency Phone:")')&.text&.split(':')&.last&.strip
        
        # Extract phone numbers safely
        phones = doc.css('td:contains("Phone") a').map { |a| a.text.strip }
        phones[0] = nil if phones[0] == '-   -'
        phones[1] = nil if phones[1] == '-   -'
        phones[2] = nil if phones[2] == '-   -'
        
        # sometimes, the website shows the email into a phone field.
        #if info[:email].to_s.empty?
            if phones[0].to_s =~ /@/
                info[:email] = phones[0]
                phones[0] = ''
            end

            if phones[1].to_s =~ /@/
                info[:email] = phones[1]
                phones[1] = ''
            end

            if phones[2].to_s =~ /@/
                info[:email] = phones[2]
                phones[2] = ''
            end
        #end

        # Assign phone numbers based on presence
        info[:phone] = !phones[0].to_s.strip.empty? ? "#{phones[0]}" : ''
        info[:phone_2] = !phones[1].to_s.strip.empty? ? "#{phones[1]}" : ''
        info[:phone_3] = !phones[2].to_s.strip.empty? ? "#{phones[2]}" : ''

        # Clean up address
        info[:address].gsub!(/.\n/, '') if info[:address]

        # CSV
        # Write the extracted information into a CSV file
        CSV.open("iatselocal52.#{c}.csv", "a+") do |csv|
            # Add data row
            csv << [info[:first_name], info[:last_name], info[:name], info[:department], info[:address], info[:phone], info[:phone_2], info[:phone_3], info[:email], info[:emergency_contact], info[:emergency_phone]]
        end

        l.done(details: td.text.blue)

        # next row
        i += 1
    end # while i < rows.size
end # ('A'..'Z').each do |c|
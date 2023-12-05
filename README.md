
THIS PROJECT IS STILL UNDER CONSTRUCTION

![Gem version](https://img.shields.io/gem/v/adspower-client) ![Gem downloads](https://img.shields.io/gem/dt/adspower-client)

# AdsPower Client

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

**Outline:**

1. [Installation](#1-installation)
2. [Scraping](#2-scraping)
3. [Advanced](#3-advanced)

## 1. Installation

Install required packages in your computer:

1. AdsPower
2. ChromeDriver
3. Scraper

**AdsPower**

1. Install [AdsPower](https://www.adspower.com/) and install it in your computer.

2. Run AdsPower and grab your API key as it is explained [here](https://help.adspower.com/docs/UsrbbM).

**ChromeDriver**

The version of ChromeDriver must be the same than the kernel of the browser you are running.

You can find all the ChromeDriver version [here](https://googlechromelabs.github.io/chrome-for-testing/).

As example, if you want to install ChromeDriver for kernel version 119, you should run the following commands:

```bash
sudo wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/116.0.5845.96/linux64/chromedriver-linux64.zip
unzip chromedriver_linux64.zip
sudo mv chromedriver-linux64 /usr/bin/chromedriver
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver
``````

For a complete guide about finding the ChromeDriver version you need, refer to [this article](https://chromedriver.chromium.org/downloads/version-selection).

**Scraper**

```bash
gem install adspower-client
```

Then, you can start a client from your Ruby code:

```ruby
client = AdsPowerClient.new(
    key: '************************',
)
```

## 2. Scraping

The `html` method perform the following operations in order to scrape any webpage stealthly:

- create a new profile
- start the browser
- visit the page
- grab the html
- quit the browser from webdriver
- stop the broser from adspower
- delete the profile
- return the html

```ruby
ret = client.html('http://foo.com')
p ret[:profile_id]
p ret[:status]
p ret[:html]
```

## 3. Advanced

Internal methods that you should handle to develop advanced bots.

**Checking AdsPower Status**

```ruby
p client.status
# => "success"
```

**Creating Profile**

```ruby
p client.create
# => "jc8y0yt"
```

**Deleting Profile**

```ruby
client.delete('jc8y0yt')
```

**Starting Profile**

```ruby
p client.start('jc8y5g3')
# => {"code"=>0, "msg"=>"success", "data"=>{"ws"=>{"puppeteer"=>"ws://127.0.0.1:43703/devtools/browser/60e1d880-e4dc-4ae0-a2d3-56d123648299", "selenium"=>"127.0.0.1:43703"}, "debug_port"=>"43703", "webdriver"=>"/home/leandro/.config/adspower_global/cwd_global/chrome_116/chromedriver"}}
```

**Stopping Profile**

```ruby
client.stop('jc8y5g3')
```

**Operating Browser**

```ruby
id = 'jc8y5g3'
url = 'https://google.com'
driver = client.driver(id)
driver.get(url)
```


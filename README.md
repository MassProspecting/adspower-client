
# AdsPower Client

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

**Outline:**

1. Installation
2. Scraping From Code
3. Running Scraping Server
4. Internals

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

## 2. Scraping From Code

```ruby
client = AdsPowerClient.new(
    key: '************************',
)

html = client.html('http://foo.com')
```

## 3. Running Scraping Server

_pending_

## 4. Internals

Internal methods are not used by end-programmers.

**Checking AdsPower Status**

```ruby
p client.status
# => "success"
```

**Creating Browser**

```ruby
p client.create
# => "jc8y0yt"
```

**Delete Browser**

```ruby
client.delete('jc8y0yt')
```

**Starting Browser**

```ruby
p client.start('jc8y5g3')
# => {"code"=>0, "msg"=>"success", "data"=>{"ws"=>{"puppeteer"=>"ws://127.0.0.1:43703/devtools/browser/60e1d880-e4dc-4ae0-a2d3-56d123648299", "selenium"=>"127.0.0.1:43703"}, "debug_port"=>"43703", "webdriver"=>"/home/leandro/.config/adspower_global/cwd_global/chrome_116/chromedriver"}}
```

**Operating Browser**

```ruby
id = 'jc8y5g3'
url = 'https://google.com'
driver = client.driver(id)
driver.get(url)
```


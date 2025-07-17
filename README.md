![Gem version](https://img.shields.io/gem/v/adspower-client) ![Gem downloads](https://img.shields.io/gem/dt/adspower-client)

# AdsPower Client

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

* [1. Installation](#1-installation)
* [2. Getting Started](#2-getting-started)
* [3. Creating Profiles](#3-creating-profiles)
* [4. Deleting Profile](#4-deleting-profile)
* [5. Retrieving Number of Profiles](#5-retrieving-number-of-profiles)
* [6. Starting Profile](#6-starting-profile)
* [7. Stopping Profile](#7-stopping-profile)
* [8. Checking if Profile is Running](#8-checking-if-profile-is-running)
* [9. Operating Browsers](#9-operating-browsers)
* [10. Starting AdsPower Server](#10-starting-adspower-server)
* [11. Stopping AdsPower Server](#11-stopping-adspower-server)
* [12. Setting AdsPower Server Port](#12-setting-adspower-server-port)
* [13. Headless Mode](#13-headless-mode)
* [14. Net‑Read Timeout](#14-net-read-timeout)
* [15. Logging](#15-logging)

## 1. Installation

```bash
gem install adspower-client
```

## 2. Getting Started

Follow the steps below to get the API-key:

1. Open the AdsPower desktop app and sign in to your account. 

2. In the sidebar, click on API.

3. Click Generate API Key, then copy the displayed key for use with AdsPower’s Local API. 

```ruby
client = AdsPowerClient.new(
    key: '******************'
)

client.online?
# => true
```

Remember to keep opened the AdsPower app in your computer, and stay logged in.

## 3. Creating Profiles

```ruby
client.create(
    name:               'Example Profile',
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'http',
        ip:             '55.55.55.55',
        port:           10001,
        user:           '**********',
        password:       '**********'
    },
    group_id:           '0'
)
# => "k11vcxmw"
```

## 4. Deleting Profile

```ruby
client.delete('k11vcxmw')
```

## 5. Retrieving Number of Profiles

```ruby
client.profile_count
# => 400011
```

## 6. Starting Profile

```ruby
client.start('jc8y5g3')
# => {"code"=>0, "msg"=>"success", "data"=>{"ws"=>{"puppeteer"=>"ws://127.0.0.1:43703/devtools/browser/60e1d880-e4dc-4ae0-a2d3-56d123648299", "selenium"=>"127.0.0.1:43703"}, "debug_port"=>"43703", "webdriver"=>"/home/leandro/.config/adspower_global/cwd_global/chrome_116/chromedriver"}}
```

## 7. Stopping Profile

```ruby
client.stop('jc8y5g3')
# => {"code"=>0, "msg"=>"success"}
```

## 8. Checking if Profile is Running

```ruby
client.check('jc8y5g3')
# => true
```

## 9. Operating Browsers

```ruby
driver = client.driver('jc8y5g3')
driver.get('https://google.com')
```

## 10. Starting AdsPower Server

If you want to run AdsPower in servers, you need a way to start the local API automatically.

```ruby
client.server_start
client.online? ? 'yes' : 'no'
# => "yes"
```

## 11. Stopping AdsPower Server

```ruby
client.server_stop
client.online? ? 'yes' : 'no'
# => "no"
```

## 12. Setting AdsPower Server Port

The server will listen the port `50325` by default. 

You can set a custom port:

```ruby
client = AdsPowerClient.new(
    key: '************************',
    port: 8082,
)
```

## 13. Headless Mode

If you start the AdsPower server by calling `server_start`, browsers will run in headless mode always.

If you are running the AdsPower GUI (aka app) instead, you can choose to start browsers in headless or not.

```ruby
# open the browser
driver = client.driver2('k11vhkyy', 
    headless: true
)
```

## 14. Net-Read Timeout

```ruby
# open the browser
driver = client.driver2('k11vhkyy', 
    read_timeout: 5000 # 5 seconds
)
```

## 15. Logging

The `server_start` method runs a bash line to start the AdsPower server.
Such a bash line redirects both `stdout` and `stderr` to `~/adspower-client.log`.

Check such a logfile if you face any problem to start the AdsPower server.

You can change the location and name for the log:

```ruby
client = AdsPowerClient.new(
    key: '************************',
    server_log: '~/foo.log'
)
```


![Gem version](https://img.shields.io/gem/v/adspower-client) ![Gem downloads](https://img.shields.io/gem/dt/adspower-client)

# AdsPower Client

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

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


---------------------------
---------------------------
---------------------------
---------------------------
---------------------------
---------------------------



## 4. Headless

This chapter explains the operations for working with the AdsPower server and browser in headless mode.

**Starting the AdsPower server**

To start the AdsPower server, use the `server_start` method:

```ruby
client = AdsPowerClient.new(key: YOUR_API_KEY)
client.server_start
```

The server will listen the port `50325` by default. 
You can set a custom port:

```ruby
client = AdsPowerClient.new(
    key: YOUR_API_KEY,
    port: 8082,
)
```

**Stopping the AdsPower server**

To stop the AdsPower server, use the `server_stop` method:

```ruby
client.server_stop
```

**Checking if the server is running**

You can verify whether the server is running with the `online?` method:

```ruby
puts client.online? ? "Server is running" : "Server is stopped"
```

**Starting a browser in headless mode**

Pass `true` as the second parameter to the `driver` method to start a browser in headless mode:

```ruby
client = AdsPowerClient.new(key: YOUR_API_KEY)
driver = client.driver(PROFILE_ID, true)
```

## 5. Logging

The `server_start` method seen in [chatper 4 (Headless)](#4-headless) runs a bash line to start the AdsPower server.

Such a bash line redirects both `stdout` and `stderr` to `~/adspower-client.log`.

Check such a logfile if you face any problem to start the AdsPower server.

Feel free to change the location and name for the log:

```ruby
client = AdsPowerClient.new(
    key: '************************',
    server_log: '~/foo.log'
)
```

## 6. New `driver2` method

From version `1.0.14`, I added a new method `driver2` that is an improvement of legacy `driver` method.

```ruby
# open the browser
driver = client.driver2(PROFILE_ID, 
    headless: HEADLESS,
    read_timeout: 200
)
```
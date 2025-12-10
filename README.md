![Gem version](https://img.shields.io/gem/v/adspower-client) ![Gem downloads](https://img.shields.io/gem/dt/adspower-client)

# AdsPower Client

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

* [1. Installation](#1-installation)
* [2. Getting Started](#2-getting-started)
* [3. Creating Profiles](#3-creating-profiles)
* [4. Deleting Profile](#4-deleting-profile)
* [5. Retrieving Number of Profile.s](#5-retrieving-number-of-profiles)
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
* [16. Safe Navigation](#16-safe-navigation)

* [ChromeDriver](#chromedriver)
* [Advanced Fingerprint Setup](#advanced-fingerprint-setup)

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

Creates a new desktop profile in AdsPower, suitable for stealth automation on a specific platform.

This method sets proxy, fingerprint, startup tabs, and optionally username/password/2FA. If you don’t provide a `fingerprint`, a default stealth-ready configuration is applied — including DNS-over-HTTPS and fingerprint consistency for anti-bot evasion.

```ruby
client.create2(
    name:            'My New Profile',
    proxy_config: {
        proxy_soft:     'other',
        proxy_type:     'socks5',
        ip:             '1.2.3.4',
        port:           1080,
        user:           'proxyuser',
        password:       'proxypass'
    },
    group_id:        '0',

    # mandatory - only applies if `fingerprint` is nil
    browser_version: '116', 

    # default: 'linux64' - only applies if `fingerprint` is nil
    os:              'linux64', 

    # saved passwords
    platform:        'x.com',
    tabs:            ['https://www.x.com/feed'],
    username:        'johndoe@example.com',
    password:        'password123',

    # optional: 2FA TOTP secret
    fakey:           'GBAIA234...'  

    # optional: Import cookies. Type: text. Format: JSON.
    cookie:          File.read('/home/leandro/Desktop/leandro-sardi.json')
)
# => "abc123xy" (profile ID)

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
driver = client.driver2('jc8y5g3')
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

## 16. Safe Navigation

When automating navigation with AdsPower + Selenium you will occasionally hit transient or session-related errors:

* `Errno::ECONNREFUSED` — chromedriver or socket closed unexpectedly.
* `Selenium::WebDriver::Error::InvalidSessionIdError` — the Selenium session was quit.
* `Selenium::WebDriver::Error::NoSuchWindowError` — the browser window was closed.

This short recipe shows a minimal, safe pattern to recover: try navigation, on failure ask the AdsPower agent to stop the remote browser (preferred), fall back to a local best-effort cleanup, wait a bit, re-attach and retry once.

```ruby
# minimal "safe navigation" example
begin
  driver.get(url)
rescue Errno::ECONNREFUSED,
       Selenium::WebDriver::Error::InvalidSessionIdError,
       Selenium::WebDriver::Error::NoSuchWindowError,
       Selenium::WebDriver::Error::WebDriverError => e

  warn "navigation error (#{e.class}): #{e.message}"

  # preferred: ask AdsPower to stop the remote browser session
  begin
    client.stop(pid)
  rescue => stop_err
    warn "client.stop failed: #{stop_err.class}: #{stop_err.message}"
    # fallback: best-effort local cleanup of cached driver object
    AdsPowerClient.cleanup(pid)
  end

  # let sockets/ports free
  sleep 1

  # re-attach / re-create driver and retry once
  driver = client.driver2(pid, headless: false)
  driver.get(url)
rescue => final_err
  warn "final navigation failed: #{final_err.class}: #{final_err.message}"
end
```

### Quick notes

* **Prefer `client.stop` first.** It asks the AdsPower agent to stop the remote browser and is the most reliable way to free external processes.
* **`AdsPowerClient.cleanup(id)` is a local, best-effort fallback** that should call `driver.quit` and *remove* the cached driver reference (use `delete(id)`, not assignment to `nil`).
* **Provide a last-resort force-kill** in your client (search processes by devtools/websocket port) only if both `quit` and `stop` fail.
* **Call a global cleanup at exit.** Implement and call `AdsPowerClient.cleanup_all` (which quits all cached drivers and deletes their keys) when your process terminates to avoid orphaned browser processes.
* **Keep retries conservative.** This example retries once after cleanup. For production tasks consider exponential backoff and bounded retry counts.

This short chapter gives a drop-in, safe pattern you can copy into your scripts. If you want, I can produce a slightly more robust `safe_navigate` helper (with retries, backoff and optional force-kill) and a patched `adspower-client.rb` that implements the force-kill and proper cleanup semantics.

## ChromeDriver

Make sure your AdsPower profile’s browser_version matches the actual version of **ChromeDriver** on disk.

You can search for versions and download links in [this JSON access point](https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json).


## Advanced Fingerprint Setup

You can override the default fingerprint entirely using the `fingerprint:` parameter. 
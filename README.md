**UNDER CONSTRUCTION**

# Scraper

Ruby gem for stealthly web-scraping and data-extraction using [AdsPower.com](https://www.adspower.com/) and proxies.

## Getting Started

Install required packages in your computer:

1. AdsPower
2. ChromeDriver
3. Scraper

**AdsPower**

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


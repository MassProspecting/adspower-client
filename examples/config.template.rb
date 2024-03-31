ADSPOWER_API_KEY = '*******'
ADSPOWER_PORT = '50325'

PROFILE_ID = 'jg2e5ck'
HEADLESS = true

MYSAAS_API_KEY = '*******'
DROPBOX_REFRESH_TOKEN = '*******-*******'

# Reference: https://github.com/leandrosardi/my-dropbox-api
BlackStack::DropBox.set({
    :vymeco_api_key => MYSAAS_API_KEY,
    :dropbox_refresh_token => DROPBOX_REFRESH_TOKEN,
})

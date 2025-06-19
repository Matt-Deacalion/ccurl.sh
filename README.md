# Use chrome session with cURL

## Fork changes
- Added `start` subcommand, to launch browser
- Added `fzf` selection, when multiple tabs match

Tired of copy pasting cURL commands from chrome to your terminal ?
You don't want to use GUI tools like Postman ?

This short bash script uses the chrome dev tools protocol to dump cookies from a specific tab of your local chrome instance into the header of a curl command
By doing so we also evade leaking cookies into our shell history file

## Usage

```sh
./ccurl.sh start [chromium-args…]
./ccurl.sh <tab-url-prefix> <curl-args...>

# example
./ccurl.sh start --incognito
./ccurl.sh "https://yandex.com" -X GET "https://api.yandex.com/some-ting"
```

## Requirements
- bash
- websocat
- jq
  
Install:  
`sudo cp ./ccurl.sh /usr/bin/ccurl && sudo chmod +x /usr/bin/ccurl`

This script was quickly hacked together. I am not a bash expert. If you see room for improvements dont hesitate to open an issue or provide a PR.

#!/bin/sh

echo '...make API call'
ipaddress=`curl -s https://ipinfo.io/ip`

# if $ipaddress is empty, exit with error
if [ -z "$ipaddress" ]; then
    echo '...no IP address returned'
    exit 1
fi

echo '...export'
export AZD_IP_ADDRESS=$ipaddress

echo '...set value'
azd env set AZD_IP_ADDRESS $ipaddress
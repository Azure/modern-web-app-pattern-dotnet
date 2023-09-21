#!/bin/sh

echo '...make API call'
ipaddress=`curl -s https://api.ipify.org`

echo '...export'
export AZD_IP_ADDRESS=$ipaddress

echo '...set value'
azd env set AZD_IP_ADDRESS $ipaddress
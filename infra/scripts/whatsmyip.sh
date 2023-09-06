#!/bin/sh

ipaddress=`curl -s https://api.ipify.org`

export AZD_IP_ADDRESS=$ipaddress
azd env set AZD_IP_ADDRESS $ipaddress
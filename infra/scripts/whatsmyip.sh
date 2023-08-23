#!/bin/sh

ipaddr=`curl -s https://api.ipify.org`

export AZD_IP_ADDRESS=$ipaddr
azd env set AZD_IP_ADDRESS $ipaddr
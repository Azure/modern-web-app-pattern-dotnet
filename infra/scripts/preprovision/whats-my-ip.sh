#!/bin/sh

# This script is executed by azd event hook preprovision and is not intended to be run manually.
# The goal is to retrieve the current machine's public IP address using the ipinfo.io API so that we can whitelist it in the Azure Dev CLI environment.

# It first checks if the network is isolated. If it is not, the script exits as no IP address info is needed.
# If the network is isolated, it makes an API call to ipinfo.io to get the IP address.
# If the API call does not return an IP address, the script exits with an error.
# If an IP address is returned, it is exported as an environment variable and set in the Azure Dev CLI environment.

isolation=(azd env get-values --output json | jq -r '.NETWORK_ISOLATION')
if [[ $isolation == "null" ]]; then
    # No IP address info needed when public network access is enabled
    exit 0
fi

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
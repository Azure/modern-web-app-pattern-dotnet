<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars

    if running without azd env "NETWORK_ISOLATION", then this script will do nothing.

    Retrieves the public IP address of the current system, as seen by Azure.  To do this, it
    uses whatsmyip.dev as an external service.  Afterwards, it sets the AZD_MYIP environment
    variable and sets the `azd env set` command to set it within Azure Developer CLI as well.
#>

$isolation = ((azd env get-values --output json) | ConvertFrom-Json).NETWORK_ISOLATION
if (-not $isolation) {
    # No IP address info needed when public network access is enabled
    exit 0
}

$ipaddr = Invoke-RestMethod -Uri https://ipinfo.io/ip

# if $ipaddress is empty, exit with error
if ([string]::IsNullOrEmpty($ipaddr)) {
    Write-Error "Unable to retrieve public IP address"
    exit 1
}

$env:AZD_IP_ADDRESS = $ipaddr
azd env set AZD_IP_ADDRESS $ipaddr
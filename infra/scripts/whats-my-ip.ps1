<#
.SYNOPSIS
    Retrieves the public IP address of the current system, as seen by Azure.  To do this, it
    uses whatsmyip.dev as an external service.  Afterwards, it sets the AZD_MYIP environment
    variable and sets the `azd env set` command to set it within Azure Developer CLI as well.
#>

$ipaddr = Invoke-RestMethod -Uri https://api.ipify.org

$env:AZD_IP_ADDRESS = $ipaddr
azd env set AZD_IP_ADDRESS $ipaddr
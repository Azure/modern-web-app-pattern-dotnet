<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_*
    This ensures the the app configuration service is reachable from the current environment.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set the required
    app configuration settings for the Relecloud web app as part of the code deployment process.



#>

# TODO - must handle multi-regional app configuration stores

Write-Host 'Set values for backend'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $Env:SQL_CONNECTION_STRING
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $Env:AZURE_STORAGE_TICKET_CONTAINER_NAME
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $Env:AZURE_STORAGE_TICKET_URI

Write-Host 'Set values for frontend'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $Env:AZURE_FRONT_DOOR_HOST_NAME
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $Env:RELECLOUD_API_BASE_URI

Write-Host 'Set values for key vault reference'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value $Env:LOGIN_ENDPOINT
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:SignedOutCallbackPath -Value /signout-oidc
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:Instance -Value $Env:LOGIN_ENDPOINT
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientSecret -Value "{ `"uri`":`"$($Env:KEY_VAULT_URI)/secrets/AzureAd--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value "{ `"uri`":`"$($Env:KEY_VAULT_URI)/secrets/$Env:REDIS_CONNECTION_SECRET_NAME`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
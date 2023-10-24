<#
.SYNOPSIS
    This script will set Relecloud required variables in Azure App Configuration Service.
    The script is only intended to be run from Azure as a deployment script that assists with the
    provisioning of Azure resources.
    
.DESCRIPTION
    The Relecloud web apps use Azure App Configuration to store config data in a
    centralized location. It is executed as part of the `azd provision` phase of the deployment
    and as such has dependencies on required Environment parameters that are set as part of the
    bicep template in the `.\infra\modules\app-config-values.bicep` template.

    Environment variables
    - APP_CONFIG_SVC_NAME: The name of the existing app configuration store.
    - AZURE_FRONT_DOOR_HOST_NAME: The hostname for Azure Front door used by the web app frontend
      to be host aware.
    - AZURE_STORAGE_TICKET_CONTAINER_NAME: Name of the Azure storage container where ticket images
      will be stored.
    - AZURE_STORAGE_TICKET_URI: URI for the Azure storage account where ticket images will be
      stored.
    - ENABLE_PUBLIC_ACCESS: Whether or not public endpoint access is allowed for this server
    - KEY_VAULT_URI: The URI for the key vault that stores the key vault referenced secrets
    - LOGIN_ENDPOINT: This endpoint is used to authenticate users and applications to access
      Microsoft services such as Azure, Office 365, and more.
    - REDIS_CONNECTION_SECRET_NAME: The key vault name for the secret storing the Redis connection
      string
    - RELECLOUD_API_BASE_URI: The baseUri used by the frontend to send API calls to the backend
    - RESOURCE_GROUP: The name of the Azure resource group that contains the APP_CONFIG_SVC_NAME
    - SQL_CONNECTION_STRING: Sql database connection string for managed identity connection.
      Note that if this connection string used a secret we would apply a Key Vault reference.

    Note: This script assumes the user has already performed Connect-AzAccount and that the Az
    module is available for performing interactions with the App Configuration resource.

    NOTE: This functionality will switch the App Configuration store to enable public network
    access so it can reach the data plane API. This approach can be mitigated if the script is
    redesigned to run from within the vnet on a DevOps agent.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
#>

try {
    $configStore = Get-AzAppConfigurationStore -Name $Env:APP_CONFIG_SVC_NAME -ResourceGroupName $Env:RESOURCE_GROUP

    Write-Host 'Open'
    Update-AzAppConfigurationStore -Name $Env:APP_CONFIG_SVC_NAME -ResourceGroupName $Env:RESOURCE_GROUP -PublicNetworkAccess 'Enabled'
    
    # Loop until the response is not empty (ie: the asynchronous firewall operation change is completed)
    while (-not $response) {
        # Attempt to set the key-value pair in Azure App Configuration
        $response = Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:CallbackPath -Value /signin-oidc


        if (-not $response) {
            Write-Host "Retrying to set the key-value pair..."
            Start-Sleep -Seconds 3 # Adjust the sleep duration as needed
        }
    }

    Write-Host 'Set values for backend'
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $Env:SQL_CONNECTION_STRING
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:Instance -Value $Env:LOGIN_ENDPOINT
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $Env:AZURE_STORAGE_TICKET_CONTAINER_NAME
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $Env:AZURE_STORAGE_TICKET_URI
    
    Write-Host 'Set values for frontend'
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $Env:AZURE_FRONT_DOOR_HOST_NAME
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $Env:RELECLOUD_API_BASE_URI
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value $Env:LOGIN_ENDPOINT
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:SignedOutCallbackPath -Value /signout-oidc
    
    Write-Host 'Set values for key vault reference'
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientSecret -Value "{ `"uri`":`"$($Env:KEY_VAULT_URI)secrets/AzureAd--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value "{ `"uri`":`"$($Env:KEY_VAULT_URI)secrets/$Env:REDIS_CONNECTION_SECRET_NAME`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  finally {
    if ($Env:ENABLE_PUBLIC_ACCESS -eq 'false') {
      Write-Host 'Close'
      Update-AzAppConfigurationStore -Name $Env:APP_CONFIG_SVC_NAME -ResourceGroupName $Env:RESOURCE_GROUP -PublicNetworkAccess 'Disabled'
    }
  }
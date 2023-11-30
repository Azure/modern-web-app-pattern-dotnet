<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_*
    This ensures the the app configuration service is reachable from the current environment.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set the required
    app configuration settings for the Relecloud web app as part of the code deployment process.

    Depends on the AZURE_RESOURCE_GROUP environment variable being set. AZD requires this to
    understand which resource group to deploy to so this script uses it to learn about the
    environment where the configuration settings should be set.

#>

function Get-WorkloadResourceGroup {
    
    # the `azd env get-values` command will return a list of stringData with the resource group name stored in the AZURE_RESOURCE_GROUP property
    $resourceGroupName = ((azd env get-values --output json) | ConvertFrom-Json).AZURE_RESOURCE_GROUP

    return Get-AzResourceGroup -Name $resourceGroupName
}

function Get-WorkloadSqlManagedIdentityConnectionString {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName
    )
    
    # the group contains tags that explain what the default name of the Azure SQL resource should be
    $sqlServerResourceName = "sql-$($group.Tags["ResourceToken"])"

    # if sql server is not found, then throw an error
    if (-not $sqlServerResourceName) {
        throw "SQL server not found in resource group $ResourceGroupName"
    }

    $sqlServerResource = Get-AzSqlServer -ServerName $sqlServerResourceName -ResourceGroupName $ResourceGroupName

    return "Server=tcp:$($sqlServerResource.FullyQualifiedDomainName),1433;Initial Catalog=$($sqlServerResourceName);Authentication=Active Directory Managed Identity"
}

function Get-WorkloadStorageAccount {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName
    )

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the storage account should be
    $storageAccountName = "st$($group.Tags["Environment"])$($group.Tags["ResourceToken"])"

    # if storage account is not found, then throw an error
    if (-not $storageAccountName) {
        throw "Storage account not found in resource group $ResourceGroupName"
    }

    return Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $ResourceGroupName
}

function Get-WorkloadKeyVault {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName
    )

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the kv should be
    $keyVaultName = "kv-$($group.Tags["ResourceToken"])"

    # if key vault is not found, then throw an error
    if (-not $keyVaultName) {
        throw "Key vault not found in resource group $ResourceGroupName"
    }

    return Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName
}

# default settings
$azureStorageTicketContainerName = "tickets" # matches the default defined in application-resources.bicep file

$resourceGroupName = (Get-WorkloadResourceGroup).ResourceGroupName

# use the resource group name to learn about the remaining required settings
$sqlConnectionString = (Get-WorkloadSqlManagedIdentityConnectionString -ResourceGroupName $resourceGroupName) # the connection string to the SQL database set with Managed Identity
$azureStorageTicketUri = (Get-WorkloadStorageAccount -ResourceGroupName $resourceGroupName).PrimaryEndpoints.Blob # the URI of the storage account container where tickets are stored
$azureFrontDoorHostName = "todo" # the hostname of the front door
$relecloudBaseUri = "todo" # used by the frontend to call the backend through the front door
$keyVaultUri = (Get-WorkloadKeyVault -ResourceGroupName $resourceGroupName).VaultUri # the URI of the key vault where secrets are stored

# display the settings so that the user can verify them in the output log
Write-Host "resourceGroupName: $resourceGroupName"
Write-Host "SqlConnectionString: $sqlConnectionString"
Write-Host "AzureStorageTicketUri: $azureStorageTicketUri"
Write-Host "AzureFrontDoorHostName: $azureFrontDoorHostName"
Write-Host "RelecloudBaseUri: $relecloudBaseUri"
Write-Host "KeyVaultUri: $keyVaultUri"

# handles multi-regional app configuration because the app config must be in the same region as the code deployment
$configStore = Get-AzAppConfigurationStore -ResourceGroupName $ResourceGroupName

# todo - verify the Redis connection strings are local to the region because they have different key names

Write-Host 'Set values for backend'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $sqlConnectionString
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $azureStorageTicketContainerName
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $azureStorageTicketUri

Write-Host 'Set values for frontend'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $azureFrontDoorHostName
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $relecloudBaseUri

Write-Host 'Set values for key vault reference'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value "{ `"uri`":`"$($keyVaultUri)secrets/`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:CallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--CallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientSecret -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:SignedOutCallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--SignedOutCallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
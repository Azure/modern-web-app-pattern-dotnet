<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars
    This ensures the the app configuration service is reachable from the current environment.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set the required
    app configuration settings for the Relecloud web app as part of the code deployment process.

    Depends on the AZURE_RESOURCE_GROUP environment variable being set. AZD requires this to
    understand which resource group to deploy to so this script uses it to learn about the
    environment where the configuration settings should be set.

#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the application resource group that was created by azd")]
    [String]$ResourceGroupName
)

# Prompt formatting features

$defaultColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[0m" } else { "" }
$successColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[32m" } else { "" }
$highlightColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[36m" } else { "" }

# End of Prompt formatting features

function Get-WorkloadSqlManagedIdentityConnectionString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting sql server connection for $highlightColor'$ResourceGroupName'$defaultColor"
    
    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the Azure SQL resource should be
    $sqlServerResourceName = "sql-$($group.Tags["ResourceToken"])"

    # if sql server is not found, then throw an error
    if ($sqlServerResourceName.Length -lt 4) {
        throw "SQL server not found in resource group $group.ResourceGroupName"
    }

    $sqlServerResource = Get-AzSqlServer -ServerName $sqlServerResourceName -ResourceGroupName $group.ResourceGroupName

    return "Server=tcp:$($sqlServerResource.FullyQualifiedDomainName),1433;Initial Catalog=$($sqlServerResourceName);Authentication=Active Directory Managed Identity"
}

function Get-WorkloadStorageAccount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting storage account for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the storage account should be
    $storageAccountName = "st$($group.Tags["Environment"])$($group.Tags["ResourceToken"])"

    # if storage account is not found, then throw an error
    if ($storageAccountName.Length -lt 6) {
        throw "Storage account not found in resource group $group.ResourceGroupName"
    }

    return Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $group.ResourceGroupName
}

function Get-MyFrontDoor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    Write-Host "`tGetting front door profile for $highlightColor'$ResourceGroupName'$defaultColor"
    return (Get-AzFrontDoorCdnProfile -ResourceGroupName $ResourceGroupName)
}

function Get-MyFrontDoorEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    $frontDoorProfile = (Get-MyFrontDoor -ResourceGroupName $ResourceGroupName)
    return (Get-AzFrontDoorCdnEndpoint -ProfileName $frontDoorProfile.Name -ResourceGroupName $ResourceGroupName)
}

function Get-WorkloadKeyVault {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting key vault for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName
    $hubGroup = Get-AzResourceGroup -Name $group.Tags["HubGroupName"]

    # the group contains tags that explain what the default name of the kv should be
    $keyVaultName = "kv-$($group.Tags["ResourceToken"])"

    # if key vault is not found, then throw an error
    if ($keyVaultName.Length -lt 4) {
        throw "Key vault not found in resource group $group.ResourceGroupName"
    }

    return Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $hubGroup.ResourceGroupName
}

function Get-RedisCacheKeyName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting redis cache key name for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # if the group contains a tag 'IsPrimary' then use the primary redis cache
    if ($group.Tags["IsPrimaryLocation"] -eq "true") {
        # matches hard coded value in application-post-config.bicep module
        return "App--RedisCache--ConnectionString-Primary"
    }

    # matches hard coded value in application-post-config.bicep module
    return "App--RedisCache--ConnectionString-Secondary"

}

Write-Host "Configuring app settings for $highlightColor'$ResourceGroupName'$defaultColor"

# default settings
$azureStorageTicketContainerName = "tickets" # matches the default defined in application-resources.bicep file

# use the resource group name to learn about the remaining required settings
$sqlConnectionString = (Get-WorkloadSqlManagedIdentityConnectionString -ResourceGroupName $ResourceGroupName) # the connection string to the SQL database set with Managed Identity
$azureStorageTicketUri = (Get-WorkloadStorageAccount -ResourceGroupName $ResourceGroupName).PrimaryEndpoints.Blob # the URI of the storage account container where tickets are stored
$azureFrontDoorHostName = "https://$((Get-MyFrontDoorEndpoint -ResourceGroupName $ResourceGroupName).HostName)" # the hostname of the front door
$relecloudBaseUri = "https://$((Get-MyFrontDoorEndpoint -ResourceGroupName $ResourceGroupName).HostName)/api" # used by the frontend to call the backend through the front door
$keyVaultUri = (Get-WorkloadKeyVault -ResourceGroupName $ResourceGroupName).VaultUri # the URI of the key vault where secrets are stored

$redisCacheKeyName = (Get-RedisCacheKeyName -ResourceGroupName $ResourceGroupName) # workloads use independent redis caches and a shared vault to store the connection string

# display the settings so that the user can verify them in the output log
Write-Host "`nWorking settings:"
Write-Host "`tresourceGroupName: $highlightColor'$resourceGroupName'$defaultColor"
Write-Host "`tSqlConnectionString: $highlightColor'$sqlConnectionString'$defaultColor"
Write-Host "`tAzureStorageTicketUri: $highlightColor'$azureStorageTicketUri'$defaultColor"
Write-Host "`tAzureFrontDoorHostName: $highlightColor'$azureFrontDoorHostName'$defaultColor"
Write-Host "`tRelecloudBaseUri: $highlightColor'$relecloudBaseUri'$defaultColor"
Write-Host "`tRedisCacheKeyName: $highlightColor'$redisCacheKeyName'$defaultColor"
Write-Host "`tKeyVaultUri: $highlightColor'$keyVaultUri'$defaultColor"

# handles multi-regional app configuration because the app config must be in the same region as the code deployment
$configStore = Get-AzAppConfigurationStore -ResourceGroupName $resourceGroupName

try {
    Write-Host "`nSet values for backend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $sqlConnectionString > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $azureStorageTicketContainerName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $azureStorageTicketUri > $null
    
    Write-Host "Set values for frontend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $azureFrontDoorHostName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $relecloudBaseUri > $null
    
    Write-Host "Set values for key vault references..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--AzureAd--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value "{ `"uri`":`"$($keyVaultUri)secrets/$($redisCacheKeyName)`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:CallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--CallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientSecret -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:SignedOutCallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--SignedOutCallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/AzureAd--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null

    Write-Host "`nFinished $($successColor)successfully$($defaultColor).`n"
}
catch {
    "Failed to set app configuration values" | Write-Error
    throw $_
}
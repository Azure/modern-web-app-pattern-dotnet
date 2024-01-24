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
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $false, HelpMessage = "Use default values for all prompts")]
    [Switch]$NoPrompt
)

if ((Get-Module -ListAvailable -Name Az.Resources) -and (Get-Module -Name Az.Resources -ErrorAction SilentlyContinue)) {
    Write-Debug "The 'Az.Resources' module is installed and imported."
    if (Get-AzContext -ErrorAction SilentlyContinue) {
        Write-Debug "The user is authenticated with Azure."
    }
    else {
        Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
        exit 10
    }
}
else {
    try {
        Write-Host "Importing 'Az.Resources' module"
        Import-Module -Name Az.Resources -ErrorAction Stop
        Write-Debug "The 'Az.Resources' module is imported successfully."
        if (Get-AzContext -ErrorAction SilentlyContinue) {
            Write-Debug "The user is authenticated with Azure."
        }
        else {
            Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
            exit 11
        }
    }
    catch {
        Write-Error "Failed to import the 'Az' module. Please install and import the 'Az' module before running this script."
        exit 12
    }
}

# Prompt formatting features

$defaultColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[0m" } else { "" }
$successColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[32m" } else { "" }
$highlightColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[36m" } else { "" }

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
    $sqlDatabaseCatalogName = "relecloud-$($group.Tags["ResourceToken"])"

    # if sql server is not found, then throw an error
    if ($sqlServerResourceName.Length -lt 4) {
        throw "SQL server not found in resource group $group.ResourceGroupName"
    }

    $sqlServerResource = Get-AzSqlServer -ServerName $sqlServerResourceName -ResourceGroupName $group.ResourceGroupName

    return "Server=tcp:$($sqlServerResource.FullyQualifiedDomainName),1433;Initial Catalog=$($sqlDatabaseCatalogName);Authentication=Active Directory Default; Connect Timeout=180"
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

# Working around https://github.com/Azure/azure-powershell/issues/17773
function Set-AzAppConfiguration-FeatureFlag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [Parameter(Mandatory = $true)]
        [string]$FeatureFlagName,
        [Parameter(Mandatory = $true)]
        [string]$FeatureFlagDescription,
        [Parameter(Mandatory = $true)]
        [bool]$FeatureFlagValue
    )

    $configValue = "{ `"id`": `"$FeatureFlagName`", `"description`": `"$FeatureFlagDescription`", `"enabled`": $($FeatureFlagValue.ToString().ToLower()), `"conditions`" : { `"client_filters`": [] } }"
    $featureFlagContentType = "application/vnd.microsoft.appconfig.ff+json;charset=utf-8"
    Set-AzAppConfigurationKeyValue -ContentType $featureFlagContentType -Endpoint $configStore.Endpoint -Key .appconfig.featureflag/$FeatureFlagName -Value $configValue > $null
}

Write-Host "Configuring app settings for $highlightColor'$ResourceGroupName'$defaultColor"

# default settings
$defaultAzureStorageTicketContainerName = "tickets" # matches the default defined in application-resources.bicep file
$defaultSqlConnectionString = (Get-WorkloadSqlManagedIdentityConnectionString -ResourceGroupName $ResourceGroupName) # the connection string to the SQL database set with Managed Identity
$defaultAzureStorageTicketUri = (Get-WorkloadStorageAccount -ResourceGroupName $ResourceGroupName).PrimaryEndpoints.Blob # the URI of the storage account container where tickets are stored
$defaultAzureFrontDoorHostName = "$((Get-MyFrontDoorEndpoint -ResourceGroupName $ResourceGroupName).HostName)" # the hostname of the front door
$defaultRelecloudBaseUri = "https://$((Get-MyFrontDoorEndpoint -ResourceGroupName $ResourceGroupName).HostName)/api" # used by the frontend to call the backend through the front door
$defaultKeyVaultUri = (Get-WorkloadKeyVault -ResourceGroupName $ResourceGroupName).VaultUri # the URI of the key vault where secrets are stored
$defaultRedisCacheKeyName = (Get-RedisCacheKeyName -ResourceGroupName $ResourceGroupName) # workloads use independent redis caches and a shared vault to store the connection string
$defaultTicketRenderRequestQueueName = "ticket-render-requests" # matches the default defined in application-resources.bicep file
$defaultTicketRenderCompleteQueueName = "ticket-render-completions" # matches the default defined in application-resources.bicep file

# Bicep templates don't yet deploy the Service Bus namespace used to communicate with the ticket rendering service, so we use a placeholder value
# here to satisfy the app configuration validation. We also default using distributed ticket rendering to false.
# Once the Service Bus namespace is deployed, we will update the app configuration to use the correct value and enable distributed ticket rendering by default.
$defaultAzureServiceBusNamespace = "placeholder" # (Get-WorkloadServiceBus -ResourceGroupName $ResourceGroupName).Namespace
$defaultUseDistributedTicketRenderingResponse = "n"

# prompt to confirm settings
$azureStorageTicketContainerName = ""
if (-not $NoPrompt) {
    $azureStorageTicketContainerName = Read-Host -Prompt "`nWhat value should be used for the Azure storage container name? [default: $highlightColor$defaultAzureStorageTicketContainerName$defaultColor]"
}

if ($azureStorageTicketContainerName -eq "") {
    $azureStorageTicketContainerName = $defaultAzureStorageTicketContainerName
}

$sqlConnectionString = ""
if (-not $NoPrompt) {
    $sqlConnectionString = Read-Host -Prompt "`nWhat value should be used for the SQL connection string? [default: $highlightColor$defaultSqlConnectionString$defaultColor]"
}

if ($sqlConnectionString -eq "") {
    $sqlConnectionString = $defaultSqlConnectionString
}

$azureStorageTicketUri = ""
if (-not $NoPrompt) {
    $azureStorageTicketUri = Read-Host -Prompt "`nWhat value should be used for the Azure storage URI? [default: $highlightColor$defaultAzureStorageTicketUri$defaultColor]"
}

if ($azureStorageTicketUri -eq "") {
    $azureStorageTicketUri = $defaultAzureStorageTicketUri
}

$azureFrontDoorHostName = ""
if (-not $NoPrompt) {
    $azureFrontDoorHostName = Read-Host -Prompt "`nWhat value should be used for the Azure Front Door Host? [default: $highlightColor$defaultAzureFrontDoorHostName$defaultColor]"
}

if ($azureFrontDoorHostName -eq "") {
    $azureFrontDoorHostName = $defaultAzureFrontDoorHostName
}

$relecloudBaseUri = ""
if (-not $NoPrompt) {
    $relecloudBaseUri = Read-Host -Prompt "`nWhat value should be used for the Relecloud Base URI? [default: $highlightColor$defaultRelecloudBaseUri$defaultColor]"
}

if ($relecloudBaseUri -eq "") {
    $relecloudBaseUri = $defaultRelecloudBaseUri
}

$keyVaultUri = ""
if (-not $NoPrompt) {
    $keyVaultUri = Read-Host -Prompt "`nWhat value should be used for the Key Vault URI? [default: $highlightColor$defaultKeyVaultUri$defaultColor]"
}

if ($keyVaultUri -eq "") {
    $keyVaultUri = $defaultKeyVaultUri
}

$redisCacheKeyName = ""
if (-not $NoPrompt) {
    $redisCacheKeyName = Read-Host -Prompt "`nWhat value should be used for the RedisCacheKeyName? [default: $highlightColor$defaultRedisCacheKeyName$defaultColor]"
}

if ($redisCacheKeyName -eq "") {
    $redisCacheKeyName = $defaultRedisCacheKeyName
}

$azureServiceBusNamespace = ""
if (-not $NoPrompt) {
    $azureServiceBusNamespace = Read-Host -Prompt "`nWhat is the namespace of the Service Bus instance for message queues? [default: $highlightColor$defaultAzureServiceBusNamespace$defaultColor]"
}

if ($azureServiceBusNamespace -eq "") {
    $azureServiceBusNamespace = $defaultAzureServiceBusNamespace
}

$ticketRenderRequestQueueName = ""
if (-not $NoPrompt) {
    $ticketRenderRequestQueueName = Read-Host -Prompt "`nWhat value should be used for the Service Bus queue storing ticket render requests? [default: $highlightColor$defaultTicketRenderRequestQueueName$defaultColor]"
}

if ($ticketRenderRequestQueueName -eq "") {
    $ticketRenderRequestQueueName = $defaultTicketRenderRequestQueueName
}

$ticketRenderCompleteQueueName = ""
if (-not $NoPrompt) {
    $ticketRenderCompleteQueueName = Read-Host -Prompt "`nWhat value should be used for the Service Bus queue storing ticket render complete messages? [default: $highlightColor$defaultTicketRenderCompleteQueueName$defaultColor]"
}

if ($ticketRenderCompleteQueueName -eq "") {
    $ticketRenderCompleteQueueName = $defaultTicketRenderCompleteQueueName
}

$useDistributedTicketRenderingResponse = ""
if (-not $NoPrompt) {
    while ($useDistributedTicketRenderingResponse -ne "y" -and $useDistributedTicketRenderingResponse -ne "n") {
        $useDistributedTicketRenderingResponse = Read-Host -Prompt "`nShould distributed ticket rendering be enabled? [y/n] [default: $highlightColor$defaultUseDistributedTicketRenderingResponse$defaultColor]"

        if ($useDistributedTicketRenderingResponse -eq "") {
            $useDistributedTicketRenderingResponse = $defaultUseDistributedTicketRenderingResponse
        }
    }
}

if ($useDistributedTicketRenderingResponse -eq "") {
    $useDistributedTicketRenderingResponse = $defaultUseDistributedTicketRenderingResponse
}

$useDistributedTicketRendering = $useDistributedTicketRenderingResponse -eq "y"

# display the settings so that the user can verify them in the output log
Write-Host "`nWorking settings:"
Write-Host "`tazureStorageTicketContainerName: $highlightColor'$azureStorageTicketContainerName'$defaultColor"
Write-Host "`tresourceGroupName: $highlightColor'$resourceGroupName'$defaultColor"
Write-Host "`tSqlConnectionString: $highlightColor'$sqlConnectionString'$defaultColor"
Write-Host "`tAzureStorageTicketUri: $highlightColor'$azureStorageTicketUri'$defaultColor"
Write-Host "`tAzureFrontDoorHostName: $highlightColor'$azureFrontDoorHostName'$defaultColor"
Write-Host "`tRelecloudBaseUri: $highlightColor'$relecloudBaseUri'$defaultColor"
Write-Host "`tRedisCacheKeyName: $highlightColor'$redisCacheKeyName'$defaultColor"
Write-Host "`tAzureServiceBusNamespace: $highlightColor'$azureServiceBusNamespace'$defaultColor"
Write-Host "`tRenderRequestQueueName: $highlightColor'$ticketRenderRequestQueueName'$defaultColor"
Write-Host "`tRenderCompleteQueueName: $highlightColor'$ticketRenderCompleteQueueName'$defaultColor"
Write-Host "`tDistributedTicketRendering: $highlightColor'$useDistributedTicketRendering'$defaultColor"

# handles multi-regional app configuration because the app config must be in the same region as the code deployment
$configStore = Get-AzAppConfigurationStore -ResourceGroupName $resourceGroupName

try {
    Write-Host "`nSet values for backend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $sqlConnectionString > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $azureStorageTicketContainerName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $azureStorageTicketUri > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:ServiceBus:Namespace -Value $azureServiceBusNamespace > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:ServiceBus:RenderRequestQueueName -Value $ticketRenderRequestQueueName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:ServiceBus:RenderCompleteQueueName -Value $ticketRenderCompleteQueueName > $null

    # Az.AppConfiguration does not support feature flags yet, so we use our own helper function
    # https://github.com/Azure/azure-powershell/issues/17773
    Set-AzAppConfiguration-FeatureFlag -Endpoint $configStore.Endpoint -FeatureFlagName "DistributedTicketRendering" -FeatureFlagDescription "Enable to render ticket images out-of-process" -FeatureFlagValue $useDistributedTicketRendering

    Write-Host "Set values for frontend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $azureFrontDoorHostName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $relecloudBaseUri > $null

    Write-Host "Set values for key vault references..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value "{ `"uri`":`"$($keyVaultUri)secrets/$($redisCacheKeyName)`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:AttendeeScope -Value "{ `"uri`":`"$($keyVaultUri)secrets/App--RelecloudApi--AttendeeScope`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:CallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--CallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:ClientSecret -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:SignedOutCallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--SignedOutCallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null

    Write-Host "`nFinished set-app-configuration $($successColor)successfully$($defaultColor).`n"
}
catch {
    "Failed to set app configuration values" | Write-Error
    throw $_
}

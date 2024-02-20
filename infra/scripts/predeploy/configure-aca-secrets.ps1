<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars
    This ensures the the app configuration service is reachable from the current environment.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set required secrets in
    Azure Containear Apps for the Relecloud web app as part of the code deployment process.

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

function Get-AzureContainerApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$NamePrefix
    )
    Write-Host "`tGetting Azure Container App with name prefix $highlightColor'$NamePrefix'$defaultColor for group $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName
    $containerAppName = "$NamePrefix-$($group.Tags["ResourceToken"])"
    return Get-AzContainerApp -ResourceGroupName $ResourceGroupName -Name $containerAppName
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

function Get-ManagedIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting app managed identity for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    $managedIdentityName = "id-app-$($group.Tags["ResourceToken"])"

    return Get-AzUserAssignedIdentity -ResourceGroupName $group.ResourceGroupName -Name $managedIdentityName
}

function Get-DefaultRenderRequestQueueSecretName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting default render request queue secret name for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName
    $isPrimaryLocation = $group.Tags["IsPrimaryLocation"]

    return "App--RenderRequestQueue--ConnectionString--$($isPrimaryLocation -eq 'true' ? 'Primary' : 'Secondary')"
}

# default settings
$defaultRendererAppName = (Get-AzureContainerApp -ResourceGroupName $ResourceGroupName -NamePrefix "aca-renderer").Name # the name of the container app
$defaultKeyVaultUri = (Get-WorkloadKeyVault -ResourceGroupName $ResourceGroupName).VaultUri # the URI of the key vault where secrets are stored
$defaultManagedIdentityId = (Get-ManagedIdentity -ResourceGroupName $ResourceGroupName).Id # the ID of the managed identity used to access the key vault
$defaultRenderRequestQueueAcaSecretName = "render-request-queue-connection-string"
$defaultRenderRequestQueueKvSecretName = Get-DefaultRenderRequestQueueSecretName -ResourceGroupName $ResourceGroupName

Write-Host "Configuring ACA secrets for $highlightColor'$ResourceGroupName'$defaultColor"

# prompt to confirm settings

# Renderer app name
$rendererAppName = ""
if (-not $NoPrompt) {
    $rendererAppName = Read-Host -Prompt  "`nEnter the name of the Renderer container app service [default: $highlightColor$defaultRendererAppName$defaultColor]"
}

if ($rendererAppName -eq "") {
    $rendererAppName = $defaultRendererAppName
}

# Key vault URI
$keyVaultUri = ""
if (-not $NoPrompt) {
    $keyVaultUri = Read-Host -Prompt  "`nEnter the URI of the key vault where secrets are stored [default: $highlightColor$defaultKeyVaultUri$defaultColor]"
}

if ($keyVaultUri -eq "") {
    $keyVaultUri = $defaultKeyVaultUri
}

# Managed identity ID
$managedIdentityId = ""
if (-not $NoPrompt) {
    $managedIdentityId = Read-Host -Prompt  "`nEnter the ID of the managed identity used to access the key vault [default: $highlightColor$defaultManagedIdentityId$defaultColor]"
}

if ($managedIdentityId -eq "") {
    $managedIdentityId = $defaultManagedIdentityId
}

# Render request queue ACA secret name
$renderRequestQueueAcaSecretName = ""
if (-not $NoPrompt) {
    $renderRequestQueueAcaSecretName = Read-Host -Prompt  "`nEnter the name of the secret in ACA for the render request queue connection string [default: $highlightColor$defaultRenderRequestQueueAcaSecretName$defaultColor]"
}

if ($renderRequestQueueAcaSecretName -eq "") {
    $renderRequestQueueAcaSecretName = $defaultRenderRequestQueueAcaSecretName
}

# Render request queue key vault secret name
$renderRequestQueueKvSecretName = ""
if (-not $NoPrompt) {
    $renderRequestQueueKvSecretName = Read-Host -Prompt  "`nEnter the name of the secret in the key vault for the render request queue connection string [default: $highlightColor$defaultRenderRequestQueueKvSecretName$defaultColor]"
}

if ($renderRequestQueueKvSecretName -eq "") {
    $renderRequestQueueKvSecretName = $defaultRenderRequestQueueKvSecretName
}

# Display the settings so the user can verify them in the output log
Write-Host "`nConfiguring ACA secrets with the following settings:"
Write-Host " `tkeyVaultUri: $highlightColor$keyVaultUri$defaultColor"
Write-Host " `tmanagedIdentityId: $highlightColor$managedIdentityId$defaultColor"
Write-Host " `trenderRequestQueueAcaSecretName: $highlightColor$renderRequestQueueAcaSecretName$defaultColor"
Write-Host " `trenderRequestQueueKvSecretName: $highlightColor$renderRequestQueueKvSecretName$defaultColor"

try {
    $renderQueueSecretUri = $keyVaultUri + "secrets/$renderRequestQueueKvSecretName"
    $renderQueueSecret = New-AzContainerAppSecretObject -Name $renderRequestQueueAcaSecretName `
                                             -KeyVaultUrl $renderQueueSecretUri `
                                             -Identity $managedIdentityId

    # Update-AzContainerApp overrides (rather than appending) secrets, so we should pass exisitng
    # secrets to the update command along with new ones.
    $existingSecrets = Get-AzContainerAppSecret -ContainerAppName $rendererAppName -ResourceGroupName $ResourceGroupName

    $configuration = New-AzContainerAppConfigurationObject -Secret $existingSecrets,$renderQueueSecret
    Update-AzContainerApp -ResourceGroupName $ResourceGroupName -Name $rendererAppName -Configuration $configuration
}
catch {
    "Failed to set app ACA secrets" | Write-Error
    throw $_
}
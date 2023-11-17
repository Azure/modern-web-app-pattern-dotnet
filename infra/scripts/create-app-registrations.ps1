<#
.SYNOPSIS
    Creates Azure AD app registrations for the call center web and api applications
    and saves the configuration data in App Configuration Svc and Key Vault.

    <This command should only be run after using the azd command to deploy resources to Azure>
    
.DESCRIPTION
    The Relecloud web app uses Azure AD to authenticate and authorize the users that can
    make concert ticket purchases. To prove that the website is a trusted, and secure, resource
    the web app must handshake with Azure AD by providing the configuration settings like the following.
    - TenantID identifies which Azure AD instance holds the users that should be authorized
    - ClientID identifies which app this code says it represents
    - ClientSecret provides a secret known only to Azure AD, and shared with the web app, to
    validate that Azure AD can trust this web app

    This script will create the App Registrations that provide these configurations. Once those
    are created the configuration data will be saved to Azure App Configuration and the secret
    will be saved in Azure Key Vault so that the web app can read these values and provide them
    to Azure AD during the authentication process.

    NOTE: This functionality assumes that the web app, app configuration service, and app
    service have already been successfully deployed.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.

.EXAMPLE
    PS C:\> .\create-app-registrations.ps1 -ResourceGroupName rele231116v1

    This example will create the app registrations for the rele231116v1 environment.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the application resource group that was created by azd")]
    [String]$ResourceGroupName
)

$MAX_RETRY_ATTEMPTS = 10

# Function definitions

function Get-CachedResourceGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    if ($global:resourceGroups -and $global:resourceGroups.ContainsKey($ResourceGroupName)) {
        return $global:resourceGroups[$ResourceGroupName]
    }

    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$global:resourceGroups) {
        $global:resourceGroups = @{}
    }

    $global:resourceGroups[$ResourceGroupName] = $resourceGroup

    return $resourceGroup
}

function Get-RelecloudWorkloadName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'rele231116v1'
    return $resourceGroup.Tags["WorkloadName"]
}

function Get-RelecloudWorkloadResourceToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'c2auhsbjt6h6i'
    return $resourceGroup.Tags["ResourceToken"]
}


function Get-RelecloudEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'dev', 'test', 'prod'
    return $resourceGroup.Tags["Environment"]
}

function Get-RelecloudFrontendAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$apiAppRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$websiteUri
    )
    
    # get an existing Relecloud Front-end App Registration
    $frontEndAppRegistration = Get-AzADApplication -DisplayName $frontEndAppRegistrationName -ErrorAction SilentlyContinue

    # if it doesn't exist, then return a new one we created
    if (!$frontEndAppRegistration) {
        return New-RelecloudFrontendAppRegistration -appRegistrationName $appRegistrationName -websiteUri $websiteUri
    }

    return $frontEndAppRegistration
}

function New-RelecloudFrontendAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$appRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$websiteUri
    )
    
    # create an Azure AD App Registration for the front-end web app
    $frontEndAppRegistration = New-AzADApplication
         -DisplayName $frontEndAppRegistrationName
         -SignInAudience "AzureADMyOrg"
         -Oauth2AllowIdTokenImplicitFlow $true
         -ReplyUrls @("https://$websiteUri/signin-oidc", "https://localhost:7227/signin-oidc")
         -LogoutUrl "https://$websiteUri/signout-oidc"
         -ErrorAction Stop

    $clientId = ""
    while ($clientId -eq "" -and $attempts -lt $MAX_RETRY_ATTEMPTS)
    {
        $MAX_RETRY_ATTEMPTS = $MAX_RETRY_ATTEMPTS + 1
        try {
            $clientId = (Get-AzADApplication -DisplayName $frontEndAppRegistrationName -ErrorAction Stop).ApplicationId
        }
        catch {
            Write-Host "`t`tFailed to retrieve the client ID for the front-end app registration. Will try again in 3 seconds."
            Start-Sleep -Seconds 3
        }
    }

    # Something like 'dev', 'test', 'prod'
    return $frontEndAppRegistration
}

# End of function definitions


# Check for required features

if ((Get-Module -ListAvailable -Name Az) -and (Get-Module -Name Az -ErrorAction SilentlyContinue)) {
    Write-Debug "The 'Az' module is installed and imported."
    if (Get-AzContext -ErrorAction SilentlyContinue) {
        Write-Debug "The user is authenticated with Azure."
    }
    else {
        Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
        exit 10
    }
}
else {
    Write-Error "The 'Az' module is not installed or imported. Please install and import the 'Az' module before running this script."
    exit 11
}

function Get-AzureFrontDoorResource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    $frontDoorName = (Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Cdn/profiles").Name

    $frontDoorResource = Get-AzFrontDoorFrontendEndpoint -ResourceGroupName $ResourceGroupName -FrontDoorName $frontDoorName -ErrorAction SilentlyContinue
    
    return $frontDoorResource
}

# End of feature checking

# Set defaults
$defaultFrontEndAppRegistrationName = "$(Get-RelecloudWorkloadName -ResourceGroupName $ResourceGroupName)-$(Get-RelecloudEnvironment -ResourceGroupName $ResourceGroupName)-front-webapp-$(Get-RelecloudWorkloadResourceToken -ResourceGroupName $ResourceGroupName)"
$defaultApiAppRegistrationName = "$(Get-RelecloudWorkloadName -ResourceGroupName $ResourceGroupName)-$(Get-RelecloudEnvironment -ResourceGroupName $ResourceGroupName)-api-webapp-$(Get-RelecloudWorkloadResourceToken -ResourceGroupName $ResourceGroupName)"
$defaultKeyVaultname = "kv-$(Get-RelecloudWorkloadResourceToken -ResourceGroupName $ResourceGroupName)"

$defaultWebsiteUri = (Get-AzureFrontDoorResource -ResourceGroupName $ResourceGroupName).FrontendEndpoints[0].HostNames[0]

# End of Set defaults

# Gather inputs

# The Relecloud web app has two websites so we need to create two app registrations.
# This app registration is for the front-end website that users will interact with.
$frontEndAppRegistrationName = Read-Host -Prompt "`nWhat should the name of the Front-end web app registration be? [default: $defaultFrontEndAppRegistrationName]"

if ($frontEndAppRegistrationName -eq "") {
    $frontEndAppRegistrationName = $defaultFrontEndAppRegistrationName
}

# This app registration is for the back-end API that the front-end website will call.
$apiAppRegistrationName = Read-Host -Prompt "`nWhat should the name of the API web app registration be? [default: $defaultApiAppRegistrationName]"

if ($apiAppRegistrationName -eq "") {
    $apiAppRegistrationName = $defaultApiAppRegistrationName
}

# This is where the App Registration details will be stored
$keyVaultName = Read-Host -Prompt "`nWhat is the name of the Key Vault that should store the App Registration details? [default: $defaultKeyVaultname]"

if ($keyVaultName -eq "") {
    $keyVaultName = $defaultKeyVaultname
}

$websiteUri = Read-Host -Prompt "`nWhat is the uri of the website? [default: $defaultWebsiteUri]"

if ($websiteUri -eq "") {
    $websiteUri = $defaultWebsiteUri
}

# End of Gather inputs

# Display working state for confirmation
Write-Host "`nRelecloud Setup for App Registrations" -ForegroundColor Yellow
Write-Host "`tresourceGroupName='$resourceGroupName'"
Write-Host "`tfrontEndAppRegistrationName='$frontEndAppRegistrationName'"
Write-Host "`tapiAppRegistrationName='$apiAppRegistrationName'"
Write-Host "`tkeyVaultName='$keyVaultName'"
Write-Host "`twebsiteUri='$websiteUri'"
Write-Host ""

$confirmation = Read-Host -Prompt "`nHit enter proceed with creating app registrations"
if ($confirmation -ne "") {
    Write-Host "`nExiting without creating app registrations."
    exit 12
}

# End of Display working state for confirmation

# Test the existence of the Key Vault
$keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue

if (!$keyVault) {
    Write-Error "The Key Vault '$keyVaultName' does not exist. Please create the Key Vault before running this script."
    exit 13
}

# Test to see if the current user has permissions to create secrets in the Key Vault
try {
    $secretValue = ConvertTo-SecureString -String 'https://login.microsoftonline.com/' -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'AzureAd--Instance' -SecretValue $secretValue -ErrorAction Stop > $null
} catch {
    Write-Error "Unable to save data to '$keyVaultName'. Please check your permissions and the network restrictions on the Key Vault."
    exit 14
}

# Set static values
$secretValue = ConvertTo-SecureString -String '/signin-oidc' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'AzureAd--CallbackPath' -SecretValue $secretValue -ErrorAction Stop > $null

$secretValue = ConvertTo-SecureString -String '/signout-oidc' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'AzureAd--SignedOutCallbackPath' -SecretValue $secretValue -ErrorAction Stop > $null


# Create the front-end app registration
$frontEndAppRegistration = Get-RelecloudFrontendAppRegistration -websiteUri $websiteUri -appRegistrationName $frontEndAppRegistrationName

# all done
exit 0
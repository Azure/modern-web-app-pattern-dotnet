targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unqiue hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Will select production ready SKUs when `true`')
param isProd string = 'false'

@description('Should specify an Azure region, if not set to none, to trigger multiregional deployment. The second region should be different than the `location` . e.g. `westus3`')
param secondaryAzureLocation string

@secure()
@description('Specifies a password that will be used to secure the Azure SQL Database')
param azureSqlPassword string = ''

// the following Azure AD B2C information can be found in the Azure portal when examining the Azure AD B2C tenant's app registration page
// read the following to learn more: https://learn.microsoft.com/en-us/azure/active-directory-b2c/tutorial-register-applications?tabs=app-reg-ga

// these AADB2C settings are also documented in the resources.bicep. Please keep both locations in sync

@minLength(1)
@description('A scope used by the front-end public web app to get authorized access to the public web api. Looks similar to https://myb2ctestorg.onmicrosoft.com/fbb6ce3b-c65f-4708-ae94-5069d1f821b4/Attendee')
param frontEndAzureAdB2CApiScope string

@minLength(1)
@description('A unique identifier of the public facing front-end web app')
param frontEndAzureAdB2cClientId string

@secure()
@minLength(1)
@description('A secret generated by Azure AD B2C so that your web app can establish trust with Azure AD B2C')
param frontEndAzureAdB2cClientSecret string

@minLength(1)
@description('A unique identifier of the public facing API web app')
param apiAzureAdB2cClientId string

@minLength(1)
@description('The domain for the Azure B2C tenant: e.g. myb2ctestorg.onmicrosoft.com')
param azureAdB2cDomain string

@minLength(1)
@description('The url for the Azure B2C tenant: e.g. https://myb2ctestorg.b2clogin.com')
param azureAdB2cInstance string

@minLength(1)
@description('A unique identifier of the Azure AD B2C tenant')
param azureAdB2cTenantId string

@minLength(1)
@description('An Azure AD B2C flow that defines behaviors relating to user sign-up and sign-in. Also known as an Azure AD B2C user flow.')
param azureAdB2cSignupSigninPolicyId string

@minLength(1)
@description('An Azure AD B2C flow that enables users to reset their passwords. Also known as an Azure AD B2C user flow.')
param azureAdB2cResetPolicyId string

@minLength(1)
@description('A URL provided by your web app that will clear session info when a user signs out')
param azureAdB2cSignoutCallback string

var isProdBool = isProd == 'true' ? true : false

var tags = {
  'azd-env-name': name
}

var isMultiLocationDeployment = secondaryAzureLocation == '' ? false : true

var primaryResourceGroupName = '${name}-rg'
var secondaryResourceGroupName = '${name}-secondary-rg'

var primaryResourceToken = toLower(uniqueString(subscription().id, primaryResourceGroupName, location))
var secondaryResourceToken = toLower(uniqueString(subscription().id, secondaryResourceGroupName, secondaryAzureLocation))

resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: primaryResourceGroupName
  location: location
  tags: tags
}

module devOpsIdentitySetup './devOpsIdentitySetup.bicep' = {
  name: 'devOpsIdentitySetup'
  scope: primaryResourceGroup
  params: {
    tags: tags
    location: location
    resourceToken: primaryResourceToken
  }
}

// temporary workaround for multiple resource group bug
// https://github.com/Azure/azure-dev/issues/690
// `azd down` expects to be able to delete this resource because it was listed by the azure deployment output even when it is not deployed
resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: secondaryResourceGroupName
  location: isMultiLocationDeployment ? secondaryAzureLocation : location
  tags: tags
}

module primaryResources './resources.bicep' = {
  name: 'primary-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    azureSqlPassword: azureSqlPassword
    devOpsManagedIdentityId: devOpsIdentitySetup.outputs.devOpsManagedIdentityId
    isProd: isProdBool
    location: location
    principalId: principalId
    resourceToken: primaryResourceToken
    tags: tags
    apiAzureAdB2cClientId: apiAzureAdB2cClientId
    azureAdB2cDomain: azureAdB2cDomain
    azureAdB2cInstance: azureAdB2cInstance
    azureAdB2cResetPolicyId: azureAdB2cResetPolicyId
    azureAdB2cSignoutCallback: azureAdB2cSignoutCallback
    azureAdB2cSignupSigninPolicyId: azureAdB2cSignupSigninPolicyId
    azureAdB2cTenantId: azureAdB2cTenantId
    frontEndAzureAdB2CApiScope: frontEndAzureAdB2CApiScope
    frontEndAzureAdB2cClientId: frontEndAzureAdB2cClientId
    frontEndAzureAdB2cClientSecret: frontEndAzureAdB2cClientSecret
  }
}

module secondaryResources './resources.bicep' = if (isMultiLocationDeployment) {
  name: 'secondary-${primaryResourceToken}'
  scope: secondaryResourceGroup
  params: {
    azureSqlPassword: azureSqlPassword
    devOpsManagedIdentityId: devOpsIdentitySetup.outputs.devOpsManagedIdentityId
    isProd: isProdBool
    location: secondaryAzureLocation
    principalId: principalId
    resourceToken: secondaryResourceToken
    tags: tags
    apiAzureAdB2cClientId: apiAzureAdB2cClientId
    azureAdB2cDomain: azureAdB2cDomain
    azureAdB2cInstance: azureAdB2cInstance
    azureAdB2cResetPolicyId: azureAdB2cResetPolicyId
    azureAdB2cSignoutCallback: azureAdB2cSignoutCallback
    azureAdB2cSignupSigninPolicyId: azureAdB2cSignupSigninPolicyId
    azureAdB2cTenantId: azureAdB2cTenantId
    frontEndAzureAdB2CApiScope: frontEndAzureAdB2CApiScope
    frontEndAzureAdB2cClientId: frontEndAzureAdB2cClientId
    frontEndAzureAdB2cClientSecret: frontEndAzureAdB2cClientSecret
  }
}

module azureFrontDoor './azureFrontDoor.bicep' = if (isMultiLocationDeployment) {
  name: 'frontDoor-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    resourceToken: primaryResourceToken
    tags: tags
    primaryBackendAddress: primaryResources.outputs.WEB_CALLCENTER_URI
    secondaryBackendAddress: isMultiLocationDeployment ? secondaryResources.outputs.WEB_CALLCENTER_URI : 'none'
  }
}

output WEB_URI string = isMultiLocationDeployment ? azureFrontDoor.outputs.WEB_URI : primaryResources.outputs.WEB_CALLCENTER_URI
output AZURE_LOCATION string = location

output DEBUG_IS_MULTI_LOCATION_DEPLOYMENT bool = isMultiLocationDeployment
output DEBUG_SECONDARY_AZURE_LOCATION string = secondaryAzureLocation
output DEBUG_IS_PROD bool = isProdBool

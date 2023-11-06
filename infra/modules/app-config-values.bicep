targetScope = 'resourceGroup'

/*
** Sets configuration data in Azure App Configuration Service
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
** #1876128 details how this script should be adjusted to run from Azure Container Instance
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', then two regional deployments will be performed.')
  isMultiLocationDeployment: bool
  
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool
  
  @description('If \'false\', then this is a multi-location deployment for the second location.')
  isPrimaryLocation: bool

  @description('The primary Azure region to host resources')
  location: string

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the existing app configuration store')
param appConfigurationStoreName string

@description('The hostname for Azure Front door used by the web app frontend to be host aware')
param azureFrontDoorHostName string

@description('Name of the Azure storage container where ticket images will be stored')
param azureStorageTicketContainerName string

@description('URI for the Azure storage account where ticket images will be stored')
param azureStorageTicketUri string

@description('The name of the identity that runs the script (requires access to change public network settings on App Configuration)')
param devopsIdentityName string

@description('The name for the key vault that stores the key vault referenced secrets')
param keyVaultName string

@description('The Azure region for the resource.')
param location string

@description('Sql database connection string for managed identity connection')
param sqlDatabaseConnectionString string

@description('The key vault name for the secret storing the Redis connection string')
param redisConnectionSecretName string

@description('The baseUri used by the frontend to send API calls to the backend')
param relecloudApiBaseUri string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Settings
*/

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

// ========================================================================
// VARIABLES
// ========================================================================

// will often be 'login.microsoft.com' but is set dynamically so that it can be modified for government clouds
var microsoftAzureAdLoginEndpoint = environment().authentication.loginEndpoint 

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appConfigStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationStoreName
}

resource devopsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: devopsIdentityName
}

resource openConfigSvcForEdits 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'openConfigSvcForEdits'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    // When the identity property is specified, the script service calls Connect-AzAccount -Identity before invoking the user script.
    userAssignedIdentities: {
      '${devopsIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azPowerShellVersion: '10.2'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'APP_CONFIG_SVC_NAME'
        value: appConfigStore.name
      }
      {
        name: 'AZURE_FRONT_DOOR_HOST_NAME'
        value: azureFrontDoorHostName
      }
      {
        name: 'AZURE_STORAGE_TICKET_CONTAINER_NAME'
        value: azureStorageTicketContainerName
      }
      {
        name: 'AZURE_STORAGE_TICKET_URI'
        value: azureStorageTicketUri
      }
      {
        name: 'ENABLE_PUBLIC_ACCESS'
        value: enablePublicNetworkAccess ? 'true' : 'false'
      }
      {
        name: 'KEY_VAULT_URI'
        value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}'
      }
      {
        name: 'LOGIN_ENDPOINT'
        value: microsoftAzureAdLoginEndpoint
      }
      {
        name: 'REDIS_CONNECTION_SECRET_NAME'
        value: redisConnectionSecretName
      }
      {
        name: 'RELECLOUD_API_BASE_URI'
        value: relecloudApiBaseUri
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'SQL_CONNECTION_STRING'
        value: sqlDatabaseConnectionString
      }
    ]
    scriptContent: loadTextContent('../scripts/update-app-config-values.ps1')
  }
}

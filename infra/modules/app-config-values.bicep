targetScope = 'resourceGroup'

/*
** Sets configuration data in Azure App Configuration Service
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

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

@description('The Azure region for the resource.')
param location string

@description('The name of the identity that runs the script (requires access to change public network settings on App Configuration)')
param devopsIdentityName string

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
    azPowerShellVersion: '10.3' 
    retentionInterval: 'P1D'
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
        name: 'LOGIN_ENDPOINT'
        value: environment().authentication.loginEndpoint 
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
    scriptContent: '''
      try {
        $configStore = Get-AzAppConfigurationStore -Name $APP_CONFIG_SVC_NAME -ResourceGroupName $RESOURCE_GROUP

        Update-AzAppConfigurationStore -Name $APP_CONFIG_SVC_NAME -PublicNetworkAccess $true

        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $SQL_CONNECTION_STRING
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:AzureAd:Instance -Value $LOGIN_ENDPOINT
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $AZURE_STORAGE_TICKET_CONTAINER_NAME
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $AZURE_STORAGE_TICKET_URI
        
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $AZURE_FRONT_DOOR_HOST_NAME
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $RELECLOUD_API_BASE_URI
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:Instance -Value $LOGIN_ENDPOINT
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:CallbackPath -Value /signin-oidc
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:SignedOutCallbackPath -Value /signout-oidc
        
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key AzureAd:ClientSecret -Value AzureAd--ClientSecret -ContentType application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8
        Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RedisCache:ConnectionString -Value $REDIS_CONNECTION_SECRET_NAME -ContentType application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8
      }
      finally {
        if ($ENABLE_PUBLIC_ACCESS -eq 'true') {
          Update-AzAppConfigurationStore -Name $APP_CONFIG_SVC_NAME -PublicNetworkAccess $true
        }
        else {
          Update-AzAppConfigurationStore -Name $APP_CONFIG_SVC_NAME -PublicNetworkAccess $false
        }
      }
      '''
  }
}

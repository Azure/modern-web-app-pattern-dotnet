targetScope = 'subscription'

/*
** Application Infrastructure
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

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// From: infra/types/FrontDoorSettings.bicep
@description('Type describing the settings for Azure Front Door.')
type FrontDoorSettings = {
  @description('The name of the Azure Front Door endpoint')
  endpointName: string

  @description('Front Door Id used for traffic restriction')
  frontDoorId: string

  @description('The hostname that can be used to access Azure Front Door content.')
  hostname: string

  @description('The profile name that is used for configuring Front Door routes.')
  profileName: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The ID of the Application Insights resource to use for App Service logging.')
param applicationInsightsId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object = {}

@description('The settings for a pre-configured Azure Front Door that provides WAF for App Services.')
param frontDoorSettings FrontDoorSettings

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the SQL Server.')
param administratorPassword string

@minLength(8)
@description('The username for the administrator account on the SQL Server.')
param administratorUsername string

@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string = ''

@description('If true, use a common App Service Plan.  If false, use a separate App Service Plan per App Service.')
param useCommonAppServicePlan bool

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

// If the sqlResourceGroup != the workload resource group, don't create a server.
var createSqlServer = resourceNames.sqlResourceGroup == resourceNames.resourceGroup

// Budget amounts
//  All values are calculated in dollars (rounded to nearest dollar) in the South Central US region.
var budget = {
  sqlDatabase: deploymentSettings.isProduction ? 457 : 15
  appServicePlan: (deploymentSettings.isProduction ? 690 : 55) * (useCommonAppServicePlan ? 1 : 2)
  virtualNetwork: deploymentSettings.isNetworkIsolated ? 4 : 0
  privateEndpoint: deploymentSettings.isNetworkIsolated ? 9 : 0
  frontDoor: deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated ? 335 : 38
}
var budgetAmount = reduce(map(items(budget), (obj) => obj.value), 0, (total, amount) => total + amount)

var redisConnectionSecretName='App--RedisCache--ConnectionString'

// describes the Azure Storage container where ticket images will be stored after they are rendered during purchase
var ticketContainerName = 'tickets'

// Built-in Azure Contributor role
var contributorRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.resourceGroup
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

/*
** Identities used by the application.
*/
module ownerManagedIdentity '../core/identity/managed-identity.bicep' = {
  name: 'owner-managed-identity'
  scope: resourceGroup
  params: {
    name: resourceNames.ownerManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module appManagedIdentity '../core/identity/managed-identity.bicep' = {
  name: 'application-managed-identity'
  scope: resourceGroup
  params: {
    name: resourceNames.appManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module ownerManagedIdentityRoleAssignment '../core/identity/resource-group-role-assignment.bicep' = {
  name: 'owner-managed-identity-role-assignment'
  scope: resourceGroup
  params: {
    identityName: ownerManagedIdentity.outputs.name
    roleId: contributorRole
    roleDescription: 'Grant the "Contributor" role to the user-assigned managed identity so it can run deployment scripts.'
  }
}

/*
** App Configuration - used for storing configuration data
*/
module appConfiguration '../core/config/app-configuration.bicep' = {
  name: 'workload-app-configuration'
  scope: resourceGroup
  params: {
    name: resourceNames.appConfiguration
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.appConfigurationPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
  }
}

module writeAppConfigValues './app-config-values.bicep' = {
  name: 'scripted-write-app-config-store-values'
  scope: resourceGroup
  params: {
    azureFrontDoorHostName: frontDoorSettings.hostname
    azureStorageTicketContainerName: ticketContainerName
    azureStorageTicketUri:storageAccount.outputs.primaryEndpoints.blob
    appConfigurationStoreName: appConfiguration.outputs.name
    enablePublicNetworkAccess: deploymentSettings.isNetworkIsolated ? false : true
    location: deploymentSettings.location
    devopsIdentityName: ownerManagedIdentityRoleAssignment.outputs.identity_name
    relecloudApiBaseUri: 'https://${frontDoorSettings.hostname}/api'
    redisConnectionSecretName: redisConnectionSecretName
    sqlDatabaseConnectionString: sqlDatabase.outputs.connection_string    
    tags: moduleTags
  }
}

/*
** Key Vault - used for storing configuration secrets
*/
module keyVault '../core/security/key-vault.bicep' = {
  name: 'workload-key-vault'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
  }
}

/*
** SQL Database
*/
module sqlServer '../core/database/sql-server.bicep' = if (createSqlServer) {
  name: 'workload-sql-server'
  scope: resourceGroup
  params: {
    name: resourceNames.sqlServer
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    firewallRules: !deploymentSettings.isProduction && !empty(clientIpAddress) ? {
      allowedIpAddresses: [ '${clientIpAddress}/32' ]
    } : null
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    sqlAdministratorPassword: administratorPassword
    sqlAdministratorUsername: administratorUsername
  }
}

module sqlDatabase '../core/database/sql-database.bicep' = {
  name: 'workload-sql-database'
  scope: az.resourceGroup(resourceNames.sqlResourceGroup)
  params: {
    name: resourceNames.sqlDatabase
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sqlServerName: createSqlServer ? sqlServer.outputs.name : resourceNames.sqlServer

    // Settings
    diagnosticSettings: diagnosticSettings
    dtuCapacity: deploymentSettings.isProduction ? 125 : 10
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.sqlDatabasePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    sku: deploymentSettings.isProduction ? 'Premium' : 'Standard'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module writeSqlAdminInfo '../core/security/key-vault-secrets.bicep' = if (createSqlServer) {
  name: 'write-sql-admin-info-to-keyvault'
  scope: resourceGroup
  params: {
    name: keyVault.outputs.name
    secrets: [
      { key: 'Relecloud--SqlAdministratorUsername', value: administratorUsername }
      { key: 'Relecloud--SqlAdministratorPassword', value: administratorPassword }
    ]
  }
}

/*
** App Services
*/
module commonAppServicePlan '../core/hosting/app-service-plan.bicep' = if (useCommonAppServicePlan) {
  name: 'workload-app-service-plan'
  scope: resourceGroup
  params: {
    name: resourceNames.commonAppServicePlan
    location: deploymentSettings.location
    tags: moduleTags
    
    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    autoScaleSettings: deploymentSettings.isProduction ? { maxCapacity: 10, minCapacity: 3 } : null
    diagnosticSettings: diagnosticSettings
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module webService './workload-appservice.bicep' = {
  name: 'workload-webservice'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    // mapping code projects to web apps by tags matching names from azure.yaml
    tags: moduleTags
    
    // Dependencies
    appConfigurationName: appConfiguration.outputs.name
    applicationInsightsId: applicationInsightsId
    appServicePlanName: useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    // uses ownerManagedIdentity with code first schema and seeding operations
    // separate approach will be researched by 1852428
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppService
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : ''
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.webAppServicePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-service'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webServiceFrontDoorRoute '../core/security/front-door-route.bicep' = if (deploymentSettings.isPrimaryLocation) {
  name: 'web-service-front-door-route'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    healthProbeMethod:'GET'
    originPath: '/'
    originPrefix: 'web-service'
    serviceAddress: webService.outputs.app_service_hostname
    routePattern: '/api/*'
    privateLinkSettings: deploymentSettings.isNetworkIsolated ? {
      privateEndpointResourceId: webService.outputs.app_service_id
      linkResourceType: 'sites'
      location: deploymentSettings.location
    } : {}
  }
}

module webFrontend './workload-appservice.bicep' = {
  name: 'workload-webfrontend'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    // mapping code projects to web apps by tags matching names from azure.yaml
    tags: moduleTags
    
    // Dependencies
    appConfigurationName: appConfiguration.outputs.name
    applicationInsightsId: applicationInsightsId
    appServicePlanName: useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: appManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppFrontend
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : ''
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.webAppFrontendPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-frontend'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webFrontendFrontDoorRoute '../core/security/front-door-route.bicep' = if (deploymentSettings.isPrimaryLocation) {
  name: 'web-frontend-front-door-route'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    originPath: '/'
    originPrefix: 'web-frontend'
    serviceAddress: webFrontend.outputs.app_service_hostname
    routePattern: '/*'
    privateLinkSettings: deploymentSettings.isNetworkIsolated ? {
      privateEndpointResourceId: webFrontend.outputs.app_service_id
      linkResourceType: 'sites'
      location: deploymentSettings.location
    } : {}
  }
}

/*
** Azure Cache for Redis
*/

module redis '../core/database/azure-cache-for-redis.bicep' = {
  name: 'workload-redis'
  scope: resourceGroup
  params: {
    name: resourceNames.redis
    location: deploymentSettings.location
    diagnosticSettings: diagnosticSettings
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    keyVaultName: keyVault.outputs.name
    keyVaultSecretName: redisConnectionSecretName
    redisCacheSku : deploymentSettings.isProduction ? 'Standard' : 'Basic'
    redisCacheFamily : 'C'
    redisCacheCapacity: deploymentSettings.isProduction ? 1 : 0
    
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.redisPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

/*
** Azure Storage
*/

module storageAccount '../core/storage/storage-account.bicep' = {
  name: 'workload-storage-account'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    name: resourceNames.storageAccount

    // Settings
    allowSharedKeyAccess: false
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.storageAccountPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

module storageAccountContainer '../core/storage/storage-account-blob.bicep' = {
  name: 'workload-storage-account-container'
  scope: resourceGroup
  params: {
    name: resourceNames.storageAccountContainer
    storageAccountName: storageAccount.outputs.name
    diagnosticSettings: diagnosticSettings
    containers: [
      { name: ticketContainerName }
    ]
  }
}

module approveFrontDoorPrivateLinks '../core/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'approve-front-door-routes'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    managedIdentityName: ownerManagedIdentityRoleAssignment.outputs.identity_name
    webAppIds: deploymentSettings.isPrimaryLocation ? [
      webFrontendFrontDoorRoute.outputs.endpoint
      webServiceFrontDoorRoute.outputs.endpoint
    ] : []
  }
}

module workloadBudget '../core/cost-management/budget.bicep' = {
  name: 'workload-budget'
  scope: resourceGroup
  params: {
    name: resourceNames.budget
    amount: budgetAmount
    contactEmails: [
      deploymentSettings.tags['azd-owner-email']
    ]
    resourceGroups: union([ resourceGroup.name ], deploymentSettings.isNetworkIsolated ? [ resourceNames.spokeResourceGroup ] : [])
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output owner_managed_identity_id string = ownerManagedIdentity.outputs.id

output service_managed_identities object[] = [
  { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal', role: 'owner'       }
  { principalId: appManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal', role: 'application' }
]

output service_web_endpoints string[] = [ deploymentSettings.isPrimaryLocation ? webFrontendFrontDoorRoute.outputs.endpoint : webFrontend.outputs.app_service_uri ]

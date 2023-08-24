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

/*
** App Configuration - used for storing configuration data
*/
module appConfiguration '../core/developer-tools/app-configuration.bicep' = {
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
      subnetId: subnets[resourceNames.spokeStorageSubnet].id
    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
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
    firewallRules: !deploymentSettings.isProduction && !empty(clientIpAddress) ? {
      allowedIpAddresses: [ '${clientIpAddress}/32' ]
    } : null
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeStorageSubnet].id
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
      subnetId: subnets[resourceNames.spokeStorageSubnet].id
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

module writeSqlConnectionReference '../core/developer-tools/app-configuration-keyvalues.bicep' = {
  name: 'write-sql-connection-reference-to-app-configuration'
  scope: resourceGroup
  params: {
    name: appConfiguration.outputs.name
    keyvalues: [
      { key: 'App:SqlDatabase:ConnectionString', value: sqlDatabase.outputs.connection_string }
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
    managedIdentityName: appManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppService
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : ''
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.webPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoor.outputs.front_door_id
    servicePrefix: 'web-callcenter-service'
    useExistingAppServicePlan: useCommonAppServicePlan
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
      name: resourceNames.webPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoor.outputs.front_door_id
    servicePrefix: 'web-callcenter-frontend'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webFrontDoorRoute '../core/security/front-door-route.bicep' = {
  name: 'web-front-door-route'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoor.outputs.endpoint_name
    frontDoorProfileName: frontDoor.outputs.profile_name
    originPrefix: 'web'
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
** Azure Front Door with Web Application Firewall
*/
module frontDoor '../core/security/front-door-with-waf.bicep' = {
  name: 'workload-front-door-with-waf'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: resourceNames.frontDoorEndpoint
    frontDoorProfileName: resourceNames.frontDoorProfile
    webApplicationFirewallName: resourceNames.webApplicationFirewall
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Service settings
    diagnosticSettings: diagnosticSettings
    managedRules: deploymentSettings.isProduction ? [
      { name: 'Microsoft_DefaultRuleSet', version: '2.0' }
      { name: 'Microsoft_BotManager_RuleSet', version: '1.0' }
    ] : []
    sku: deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated ? 'Premium' : 'Standard'
  }
}

module approveFrontDoorPrivateLinks '../core/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'approve-front-door-routes'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    managedIdentityName: ownerManagedIdentity.outputs.name
  }
  dependsOn: [
    webFrontDoorRoute
  ]
}

module writeFrontDoorConfig '../core/developer-tools/app-configuration-keyvalues.bicep' = {
  name: 'write-front-door-config-to-app-configuration'
  scope: resourceGroup
  params: {
    name: appConfiguration.outputs.name
    keyvalues: [
      { key: 'App:FrontDoorHostname', value: frontDoor.outputs.hostname }
    ]
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

output service_web_endpoints string[] = [ webFrontDoorRoute.outputs.endpoint ]

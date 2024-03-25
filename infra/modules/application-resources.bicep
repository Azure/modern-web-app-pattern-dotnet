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
  @description('If \'true\', then two regional deployments will be performed.')
  isMultiLocationDeployment: bool

  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

  @description('The Azure region to host resources')
  location: string

  @description('The Azure region to host primary resources. In a multi-region deployment, this will match \'location\' while deploying the primary region\'s resources.')
  primaryLocation: string

  @description('The secondary Azure region in a multi-region deployment. This will match \'location\' while deploying the secondary region\'s resources during a multi-region deployment.')
  secondaryLocation: string

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

@description('When deploying a hub, the private endpoints will need this parameter to specify the resource group that holds the Private DNS zones')
param dnsResourceGroupName string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object = {}

@description('The settings for a pre-configured Azure Front Door that provides WAF for App Services.')
param frontDoorSettings FrontDoorSettings

@description('The name of the shared Azure Container Registry used in network isolated scenarios.')
param sharedAzureContainerRegistry string = ''

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the SQL Server.')
param databasePassword string

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

// True if deploying into the primary region in a multi-region deployment, otherwise false
var isPrimaryLocation = deploymentSettings.location == deploymentSettings.primaryLocation

// If the sqlResourceGroup != the application resource group, don't create a server.
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

// describes the Azure Storage container where ticket images will be stored after they are rendered during purchase
var ticketContainerName = 'tickets'

// Service Bus queues used for ticket rendering
// Match the names in set-app-configuration.ps1
var renderingQueues = [
  {
    name: 'ticket-render-requests'
    authorizationRules: [
      {
        name: 'manage-render-queue-policy'
        rights: [
          'Listen'
          'Manage'
          'Send'
        ]
      }
    ]
  }
  {
    name: 'ticket-render-completions'


    // This is a workaround for a bug in the service bus module https://github.com/Azure/ResourceModules/issues/2867
    // Authorization rules should be optional and not required when using RBAC roles, but due to the bug, we need to
    // provide an empty array explicitly.
    authorizationRules: []
  }
]

// Built-in Azure Contributor role
var contributorRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Allows push and pull access to Azure Container Registry images.
var containerRegistryPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

// Allows pull access to Azure Container Registry images.
var containerRegistryPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// Allows all operations on a Service Bus namespace.
var serviceBusDataOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'

// Allows sending messages to a Service Bus namespace's queues and topics.
var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'

// Allows receiving messages to a Service Bus namespace's queues and topics.
var serviceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

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
  name: 'application-app-configuration'
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
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.appConfigurationPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id

    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
  }
}

/*
** Key Vault - used for storing configuration secrets.
** This vault is deployed with the application when not using Network Isolation.
*/
module keyVault '../core/security/key-vault.bicep' = if (!deploymentSettings.isNetworkIsolated) {
  name: 'application-key-vault'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: true
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
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
  name: 'application-sql-server'
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
    sqlAdministratorPassword: databasePassword
    sqlAdministratorUsername: administratorUsername
  }
}

module sqlDatabase '../core/database/sql-database.bicep' = {
  name: 'application-sql-database'
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
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.sqlDatabasePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    sku: deploymentSettings.isProduction ? 'Premium' : 'Standard'
    zoneRedundant: deploymentSettings.isProduction
  }
}

/*
** App Services
*/
module commonAppServicePlan '../core/hosting/app-service-plan.bicep' = if (useCommonAppServicePlan) {
  name: 'application-app-service-plan'
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

module webService './application-appservice.bicep' = {
  name: 'application-webservice'
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
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.webAppServicePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-service'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webServiceFrontDoorRoute '../core/security/front-door-route.bicep' = if (isPrimaryLocation) {
  name: 'web-service-front-door-route'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    healthProbeMethod:'GET'
    originPath: '/api/'
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

module webFrontend './application-appservice.bicep' = {
  name: 'application-webfrontend'
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
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.webAppFrontendPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-frontend'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webFrontendFrontDoorRoute '../core/security/front-door-route.bicep' = if (isPrimaryLocation) {
  name: 'web-frontend-front-door-route'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    healthProbeMethod:'GET'
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
  name: 'application-redis'
  scope: resourceGroup
  params: {
    name: resourceNames.redis
    location: deploymentSettings.location
    diagnosticSettings: diagnosticSettings
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    // vault provided by Hub resource group when network isolated
    redisCacheSku : deploymentSettings.isProduction ? 'Standard' : 'Basic'
    redisCacheFamily : 'C'
    redisCacheCapacity: deploymentSettings.isProduction ? 1 : 0

    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
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
  name: 'application-storage-account'
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
    contributorIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.storageAccountPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

module storageAccountContainer '../core/storage/storage-account-blob.bicep' = {
  name: 'application-storage-account-container'
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

module approveFrontDoorPrivateLinks '../core/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated && isPrimaryLocation) {
  name: 'approve-front-door-routes'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    managedIdentityName: ownerManagedIdentityRoleAssignment.outputs.identity_name
  }
  // private endpoint approval between front door and web app depends on both resources
  dependsOn: [
    webService
    webServiceFrontDoorRoute
    webFrontend
    webFrontendFrontDoorRoute
  ]
}

module applicationBudget '../core/cost-management/budget.bicep' = {
  name: 'application-budget'
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

/*
** Azure Service Bus
*/

module serviceBusNamespace 'br/public:avm/res/service-bus/namespace:0.2.3' = {
  name: 'application-service-bus-namespace'
  scope: resourceGroup
  params: {
    name: resourceNames.serviceBusNamespace
    location: deploymentSettings.location
    tags: moduleTags
    skuObject: {
      name: (deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated) ? 'Premium' : 'Basic'
      capacity: 1
    }

    diagnosticSettings:[
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]

    // Settings
    minimumTlsVersion: '1.2'
    publicNetworkAccess: deploymentSettings.isNetworkIsolated ? 'Disabled' : 'Enabled'
    zoneRedundant: deploymentSettings.isProduction
    networkRuleSets: deploymentSettings.isNetworkIsolated ? {
      publicNetworkAccess: 'Disabled'
      trustedServiceAccessEnabled: false
    } : null

    // Ideally this would be disabled, but it is required for ACA scaling rules to be able to
    // trigger based on Service Bus metrics.
    // If, in the future, ACA scaling rules can authenticate with managed identity then this
    // should be set to true.
    // https://github.com/microsoft/azure-container-apps/issues/592
    disableLocalAuth: false

    // This is a workaround for a bug in the service bus module https://github.com/Azure/ResourceModules/issues/2867
    // Authorization rules should be optional and not required when using RBAC roles, but due to the bug, we need to
    // provide an empty array explicitly.
    authorizationRules:[]

    privateEndpoints: deploymentSettings.isNetworkIsolated ?  [
      {
        name: resourceNames.serviceBusNamespacePrivateEndpoint
        service: 'namespace'
        privateDnsZoneGroupName: dnsResourceGroupName
        privateDnsZoneResourceIds: [
          resourceId(subscription().subscriptionId, dnsResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.servicebus.windows.net')
        ]
        subnetResourceId: subnets[resourceNames.spokePrivateEndpointSubnet].id
        tags: moduleTags
      }
    ] : null

    roleAssignments: [
      {
        principalId: deploymentSettings.principalId
        principalType: deploymentSettings.principalType
        roleDefinitionIdOrName: serviceBusDataOwnerRoleId
      }
      {
        principalId: ownerManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: serviceBusDataOwnerRoleId
      }
      {
        principalId: appManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: serviceBusDataSenderRoleId
      }
      {
        principalId: appManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: serviceBusDataReceiverRoleId
      }
    ]

    queues: [ for queue in renderingQueues: {
        name: queue.name
        authorizationRules: queue.authorizationRules
      }
    ]
  }
}


/*
** Azure Container Registry
** The registry is deployed with the application when not using network isolation. When using network isolation, the registry is deployed with the hub.
*/

module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.0' = if (!deploymentSettings.isNetworkIsolated) {
  name: 'application-container-registry'
  scope: resourceGroup
  params: {
    name: resourceNames.containerRegistry
    location: deploymentSettings.location
    tags: moduleTags
    acrSku: deploymentSettings.isProduction ? 'Premium' :  'Basic'

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]

    // Settings
    acrAdminUserEnabled: false
    anonymousPullEnabled: false
    exportPolicyStatus: 'disabled'
    zoneRedundancy: deploymentSettings.isProduction ? 'Enabled' : 'Disabled'
    publicNetworkAccess: deploymentSettings.isProduction ? 'Disabled' : 'Enabled'
    roleAssignments: [
      {
        principalId: deploymentSettings.principalId
        principalType: deploymentSettings.principalType
        roleDefinitionIdOrName: containerRegistryPushRoleId
      }
      {
        principalId: ownerManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: containerRegistryPushRoleId
      }
      {
        principalId: appManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: containerRegistryPullRoleId
      }
    ]
  }
}

/*
** A reference to the shared container registry deployed in the hub in network-isolated scenarios.
*/

resource sharedRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = if (deploymentSettings.isNetworkIsolated) {
  name: sharedAzureContainerRegistry
  scope: az.resourceGroup(resourceNames.hubResourceGroup)
}

/*
** Azure Container Registry role assignments
** If the container registry was created in the hub, assign roles for the application identities.
*/

module containerRegistryRoleAssignments '../core/identity/container-registry-role-assignments.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'acr-role-assignments-${deploymentSettings.location}'
  scope: az.resourceGroup(resourceNames.hubResourceGroup)
  params: {
    acrName: sharedRegistry.name
    pushIdentities: [
      {
        principalId: ownerManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
      }
    ]
    pullIdentities: [
      {
        principalId: appManagedIdentity.outputs.principal_id
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

/*
** Azure Container Apps managed environment
*/

module containerAppEnvironment './application-container-apps.bicep' = {
  name: 'application-container-apps'
  scope: resourceGroup

  dependsOn : [
    containerRegistryRoleAssignments
  ]

  params: {
    deploymentSettings: deploymentSettings
    tags: moduleTags

    // Dependencies
    appConfigurationName: appConfiguration.outputs.name
    containerRegistryLoginServer: deploymentSettings.isNetworkIsolated ? sharedRegistry.properties.loginServer : containerRegistry.outputs.loginServer
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: appManagedIdentity.outputs.name
    renderRequestServiceBusNamespace: serviceBusNamespace.outputs.name
    renderRequestServiceBusQueueName: 'ticket-render-requests'

    // Settings
    containerAppEnvironmentName: resourceNames.commonContainerAppEnvironment
    renderingServiceContainerAppName: resourceNames.renderingServiceContainerApp
    subnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeContainerAppsEnvironmentSubnet].id : null
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output app_config_uri string = appConfiguration.outputs.app_config_uri
output key_vault_name string = deploymentSettings.isNetworkIsolated ? resourceNames.keyVault : keyVault.outputs.name
output redis_cache_name string = redis.outputs.name
output container_registry_login_server string = deploymentSettings.isNetworkIsolated ? sharedRegistry.properties.loginServer : containerRegistry.outputs.loginServer
output service_bus_name string = serviceBusNamespace.outputs.name

output owner_managed_identity_id string = ownerManagedIdentity.outputs.id
output app_managed_identity_id string = appManagedIdentity.outputs.id

output service_managed_identities object[] = [
  { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal', role: 'owner'       }
  { principalId: appManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal', role: 'application' }
]

output service_web_endpoints string[] = [ isPrimaryLocation ? webFrontendFrontDoorRoute.outputs.endpoint : webFrontend.outputs.app_service_uri ]
output web_uri string = isPrimaryLocation ? webFrontendFrontDoorRoute.outputs.uri : webFrontend.outputs.app_service_uri

output sql_server_name string = sqlServer.outputs.name
output sql_database_name string = sqlDatabase.outputs.name

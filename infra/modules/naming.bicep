targetScope = 'subscription'

/*
** Resource Naming
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Provides a name for every resource that may be created.
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

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('A differentiator for the environment.  Set this to a build number or date to ensure that the resource groups and resources are unique.')
param differentiator string = ''

@description('The overrides for the naming scheme.  Load this from the naming.overrides.jsonc file.')
param overrides object = {}

// ========================================================================
// VARIABLES
// ========================================================================

// A unique token that is used as a differentiator for all resources.  All resources within the
// same deployment will have the same token.
var resourceToken = uniqueString(subscription().id, deploymentSettings.name, deploymentSettings.stage, deploymentSettings.location, differentiator)

// The prefix for resource groups
var diffPrefix = !empty(differentiator) ? '-${differentiator}' : ''
var hubResourceGroupPrefix = 'rg-${deploymentSettings.name}-${deploymentSettings.stage}-${deploymentSettings.location}'
var resourceGroupPrefix = '${hubResourceGroupPrefix}${diffPrefix}'

// The list of resource names that are used in the deployment.  The default
// names use Cloud Adoption Framework abbreviations.
// See: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
var defaultResourceNames = {
  // Hub network resources
  hubBastionHost: 'bas-${resourceToken}'
  hubBastionPublicIpAddress: 'pip-bas-${resourceToken}'
  hubBudget: 'budget-hub-${resourceToken}'
  hubDDoSProtectionPlan: 'ddos-${resourceToken}'
  hubFirewall: 'afw-${resourceToken}'
  hubFirewallPublicIpAddress: 'pip-afw-${resourceToken}'
  hubJumphost: 'vm-jump-${resourceToken}'
  hubResourceGroup: '${hubResourceGroupPrefix}-hub'
  hubRouteTable: 'rt-${resourceToken}'
  hubSubnetBastionHost: 'AzureBastionSubnet'
  hubSubnetFirewall: 'AzureFirewallSubnet'
  hubSubnetJumphost: 'JumphostSubnet'
  hubSubnetPrivateEndpoint: 'PrivateEndpointSubnet'
  hubVirtualNetwork: 'vnet-hub-${resourceToken}'

  // Spoke network resources
  spokeApiInboundSubnet: 'API-Inbound'
  spokeApiInboundNSG: 'nsg-api-in-${resourceToken}'
  spokeApiOutboundSubnet: 'API-Outbound'
  spokeApiOutboundNSG: 'nsg-api-out-${resourceToken}'
  spokeDevopsSubnet: 'DevopsBuildAgents'
  spokeDeploymentSubnet: 'Deployment'
  spokeResourceGroup: '${resourceGroupPrefix}-spoke'
  spokePrivateEndpointNSG: 'nsg-pep-${resourceToken}'
  spokePrivateEndpointSubnet: 'Private-Endpoints'
  spokeVirtualNetwork: 'vnet-spoke-${resourceToken}'
  spokeWebInboundSubnet: 'Web-Inbound-${resourceToken}'
  spokeWebInboundNSG: 'nsg-web-in-${resourceToken}'
  spokeWebOutboundSubnet: 'Web-Outbound-${resourceToken}'
  spokeWebOutboundNSG: 'nsg-web-out-${resourceToken}'

  // Common resources - may be in hub or workload resource group
  applicationInsights: 'appi-${resourceToken}'
  buildAgent: 'vm-buildagent-${resourceToken}'
  logAnalyticsWorkspace: 'log-${resourceToken}'

  // Workload resources
  apiAppService: 'app-api-${resourceToken}'
  apiAppServicePlan: 'asp-api-${resourceToken}'
  apiPrivateEndpoint: 'pep-api-${resourceToken}'
  appConfiguration: 'appconfig-${resourceToken}'
  appConfigurationPrivateEndpoint: 'pep-appconfig-${resourceToken}'
  appManagedIdentity: 'id-app-${resourceToken}'
  budget: 'budget-${deploymentSettings.name}-${deploymentSettings.stage}-${deploymentSettings.location}${diffPrefix}'
  commonAppServicePlan: 'asp-common-${resourceToken}'
  frontDoorEndpoint: 'fde-${resourceToken}'
  frontDoorProfile: 'afd-${resourceToken}'
  keyVault: 'kv-${resourceToken}'
  keyVaultPrivateEndpoint: 'pep-kv-${resourceToken}'
  ownerManagedIdentity: 'id-owner-${resourceToken}'
  resourceGroup: '${resourceGroupPrefix}-workload'
  redis: 'redis-${resourceToken}'
  redisPrivateEndpoint: 'pep-redis-${resourceToken}'
  storageAccount: 'st${deploymentSettings.stage}${resourceToken}'
  storageAccountPrivateEndpoint: 'pep-st-${resourceToken}'
  storageAccountContainer: 'tickets'
  sqlDatabase: 'relecloud-${resourceToken}'
  sqlDatabasePrivateEndpoint: 'pep-sqldb-${resourceToken}'
  sqlServer: 'sql-${resourceToken}'
  sqlResourceGroup: '${resourceGroupPrefix}-workload'
  webAppFrontend: 'app-webfrontend-${resourceToken}'
  webAppService: 'app-webservice-${resourceToken}'
  webAppServicePlan: 'asp-web-${resourceToken}'
  webApplicationFirewall: 'waf${resourceToken}'
  webAppFrontendPrivateEndpoint: 'pep-web-frontend-${resourceToken}'
  webAppServicePrivateEndpoint: 'pep-web-service-${resourceToken}'
}

// ========================================================================
// OUTPUTS
// ========================================================================

output resourceToken string = resourceToken

output resourceNames object = {
  // Hub network resources
  hubBastionHost: contains(overrides, 'hubBastionHost') && !empty(overrides.hubBastionHost) ? overrides.hubBastionHost : defaultResourceNames.hubBastionHost
  hubBastionPublicIpAddress: contains(overrides, 'hubBastionPublicIpAddress') && !empty(overrides.hubBastionPublicIpAddress) ? overrides.hubBastionPublicIpAddress : defaultResourceNames.hubBastionPublicIpAddress
  hubBudget: contains(overrides, 'hubBudget') && !empty(overrides.hubBudget) ? overrides.hubBudget : defaultResourceNames.hubBudget
  hubDDoSProtectionPlan: contains(overrides, 'hubDDoSProtectionPlan') && !empty(overrides.hubDDoSProtectionPlan) ? overrides.hubDDoSProtectionPlan : defaultResourceNames.hubDDoSProtectionPlan
  hubFirewall: contains(overrides, 'hubFirewall') && !empty(overrides.hubFirewall) ? overrides.hubFirewall : defaultResourceNames.hubFirewall
  hubFirewallPublicIpAddress: contains(overrides, 'hubFirewallPublicIpAddress') && !empty(overrides.hubFirewallPublicIpAddress) ? overrides.hubFirewallPublicIpAddress : defaultResourceNames.hubFirewallPublicIpAddress
  hubJumphost: contains(overrides, 'hubJumphost') && !empty(overrides.hubJumphost) ? overrides.hubJumphost : defaultResourceNames.hubJumphost
  hubResourceGroup: contains(overrides, 'hubResourceGroup') && !empty(overrides.hubResourceGroup) ? overrides.hubResourceGroup : defaultResourceNames.hubResourceGroup
  hubRouteTable: contains(overrides, 'hubRouteTable') && !empty(overrides.hubRouteTable) ? overrides.hubRouteTable : defaultResourceNames.hubRouteTable
  hubSubnetBastionHost: contains(overrides, 'hubSubnetBastionHost') && !empty(overrides.hubSubnetBastionHost) ? overrides.hubSubnetBastionHost : defaultResourceNames.hubSubnetBastionHost
  hubSubnetFirewall: contains(overrides, 'hubSubnetFirewall') && !empty(overrides.hubSubnetFirewall) ? overrides.hubSubnetFirewall : defaultResourceNames.hubSubnetFirewall
  hubSubnetJumphost: contains(overrides, 'hubSubnetJumphost') && !empty(overrides.hubSubnetJumphost) ? overrides.hubSubnetJumphost : defaultResourceNames.hubSubnetJumphost
  hubSubnetPrivateEndpoint: contains(overrides, 'hubSubnetPrivateEndpoint') && !empty(overrides.hubSubnetPrivateEndpoint) ? overrides.hubSubnetPrivateEndpoint : defaultResourceNames.hubSubnetPrivateEndpoint
  hubVirtualNetwork: contains(overrides, 'hubVirtualNetwork') && !empty(overrides.hubVirtualNetwork) ? overrides.hubVirtualNetwork : defaultResourceNames.hubVirtualNetwork

  // Spoke network resources
  spokeApiInboundSubnet: contains(overrides, 'spokeApiInboundSubnet') && !empty(overrides.spokeApiInboundSubnet) ? overrides.spokeApiInboundSubnet : defaultResourceNames.spokeApiInboundSubnet
  spokeApiInboundNSG: contains(overrides, 'spokeApiInboundNSG') && !empty(overrides.spokeApiInboundNSG) ? overrides.spokeApiInboundNSG : defaultResourceNames.spokeApiInboundNSG
  spokeApiOutboundSubnet: contains(overrides, 'spokeApiOutboundSubnet') && !empty(overrides.spokeApiOutboundSubnet) ? overrides.spokeApiOutboundSubnet : defaultResourceNames.spokeApiOutboundSubnet
  spokeApiOutboundNSG: contains(overrides, 'spokeApiOutboundNSG') && !empty(overrides.spokeApiOutboundNSG) ? overrides.spokeApiOutboundNSG : defaultResourceNames.spokeApiOutboundNSG
  spokeDevopsSubnet: contains(overrides, 'spokeDevopsSubnet') && !empty(overrides.spokeDevopsSubnet) ? overrides.spokeDevopsSubnet : defaultResourceNames.spokeDevopsSubnet
  spokeDeploymentSubnet: contains(overrides, 'spokeDeploymentSubnet') && !empty(overrides.spokeDeploymentSubnet) ? overrides.spokeDeploymentSubnet : defaultResourceNames.spokeDeploymentSubnet
  spokeResourceGroup: contains(overrides, 'spokeResourceGroup') && !empty(overrides.spokeResourceGroup) ? overrides.spokeResourceGroup : defaultResourceNames.spokeResourceGroup
  spokePrivateEndpointNSG: contains(overrides, 'spokePrivateEndpointNSG') && !empty(overrides.spokePrivateEndpointNSG) ? overrides.spokePrivateEndpointNSG : defaultResourceNames.spokePrivateEndpointNSG
  spokePrivateEndpointSubnet: contains(overrides, 'spokePrivateEndpointSubnet') && !empty(overrides.spokePrivateEndpointSubnet) ? overrides.spokePrivateEndpointSubnet : defaultResourceNames.spokePrivateEndpointSubnet
  spokeVirtualNetwork: contains(overrides, 'spokeVirtualNetwork') && !empty(overrides.spokeVirtualNetwork) ? overrides.spokeVirtualNetwork : defaultResourceNames.spokeVirtualNetwork
  spokeWebInboundSubnet: contains(overrides, 'spokeWebInboundSubnet') && !empty(overrides.spokeWebInboundSubnet) ? overrides.spokeWebInboundSubnet : defaultResourceNames.spokeWebInboundSubnet
  spokeWebInboundNSG: contains(overrides, 'spokeWebInboundNSG') && !empty(overrides.spokeWebInboundNSG) ? overrides.spokeWebInboundNSG : defaultResourceNames.spokeWebInboundNSG
  spokeWebOutboundSubnet: contains(overrides, 'spokeWebOutboundSubnet') && !empty(overrides.spokeWebOutboundSubnet) ? overrides.spokeWebOutboundSubnet : defaultResourceNames.spokeWebOutboundSubnet
  spokeWebOutboundNSG: contains(overrides, 'spokeWebOutboundNSG') && !empty(overrides.spokeWebOutboundNSG) ? overrides.spokeWebOutboundNSG : defaultResourceNames.spokeWebOutboundNSG

  // Common services - may be in hub or workload resource group
  applicationInsights: contains(overrides, 'applicationInsights') && !empty(overrides.applicationInsights) ? overrides.applicationInsights : defaultResourceNames.applicationInsights
  buildAgent: contains(overrides, 'buildAgent') && !empty(overrides.buildAgent) ? overrides.buildAgent : defaultResourceNames.buildAgent
  logAnalyticsWorkspace: contains(overrides, 'logAnalyticsWorkspace') && !empty(overrides.logAnalyticsWorkspace) ? overrides.logAnalyticsWorkspace : defaultResourceNames.logAnalyticsWorkspace

  // Workload resources
  apiAppService: contains(overrides, 'apiAppService') && !empty(overrides.apiAppService) ? overrides.apiAppService : defaultResourceNames.apiAppService
  apiAppServicePlan: contains(overrides, 'apiAppServicePlan') && !empty(overrides.apiAppServicePlan) ? overrides.apiAppServicePlan : defaultResourceNames.apiAppServicePlan
  apiPrivateEndpoint: contains(overrides, 'apiPrivateEndpoint') && !empty(overrides.apiPrivateEndpoint) ? overrides.apiPrivateEndpoint : defaultResourceNames.apiPrivateEndpoint
  appConfiguration: contains(overrides, 'appConfiguration') && !empty(overrides.appConfiguration) ? overrides.appConfiguration : defaultResourceNames.appConfiguration
  appConfigurationPrivateEndpoint: contains(overrides, 'appConfigurationPrivateEndpoint') && !empty(overrides.appConfigurationPrivateEndpoint) ? overrides.appConfigurationPrivateEndpoint : defaultResourceNames.appConfigurationPrivateEndpoint
  appManagedIdentity: contains(overrides, 'appManagedIdentity') && !empty(overrides.appManagedIdentity) ? overrides.appManagedIdentity : defaultResourceNames.appManagedIdentity
  budget: contains(overrides, 'budget') && !empty(overrides.budget) ? overrides.budget : defaultResourceNames.budget
  commonAppServicePlan: contains(overrides, 'commonAppServicePlan') && !empty(overrides.commonAppServicePlan) ? overrides.commonAppServicePlan : defaultResourceNames.commonAppServicePlan
  frontDoorEndpoint: contains(overrides, 'frontDoorEndpoint') && !empty(overrides.frontDoorEndpoint) ? overrides.frontDoorEndpoint : defaultResourceNames.frontDoorEndpoint
  frontDoorProfile: contains(overrides, 'frontDoorProfile') && !empty(overrides.frontDoorProfile) ? overrides.frontDoorProfile : defaultResourceNames.frontDoorProfile
  keyVault: contains(overrides, 'keyVault') && !empty(overrides.keyVault) ? overrides.keyVault : defaultResourceNames.keyVault
  keyVaultPrivateEndpoint: contains(overrides, 'keyVaultPrivateEndpoint') && !empty(overrides.keyVaultPrivateEndpoint) ? overrides.keyVaultPrivateEndpoint : defaultResourceNames.keyVaultPrivateEndpoint
  ownerManagedIdentity: contains(overrides, 'ownerManagedIdentity') && !empty(overrides.ownerManagedIdentity) ? overrides.ownerManagedIdentity : defaultResourceNames.ownerManagedIdentity
  redis: contains(overrides, 'redis') && !empty(overrides.redis) ? overrides.redis : defaultResourceNames.redis
  redisPrivateEndpoint: contains(overrides, 'redisPrivateEndpoint') && !empty(overrides.redisPrivateEndpoint) ? overrides.redisPrivateEndpoint : defaultResourceNames.redisPrivateEndpoint
  resourceGroup: contains(overrides, 'resourceGroup') && !empty(overrides.resourceGroup) ? overrides.resourceGroup : defaultResourceNames.resourceGroup
  storageAccount: contains(overrides, 'storageAccount') && !empty(overrides.storageAccount) ? overrides.storageAccount : defaultResourceNames.storageAccount
  storageAccountPrivateEndpoint: contains(overrides, 'storageAccountPrivateEndpoint') && !empty(overrides.storageAccountPrivateEndpoint) ? overrides.storageAccountPrivateEndpoint : defaultResourceNames.storageAccountPrivateEndpoint
  storageAccountContainer: contains(overrides, 'storageAccountContainer') && !empty(overrides.storageAccountContainer) ? overrides.storageAccountContainer : defaultResourceNames.storageAccountContainer
  sqlDatabase: contains(overrides, 'sqlDatabase') && !empty(overrides.sqlDatabase) ? overrides.sqlDatabase : defaultResourceNames.sqlDatabase
  sqlDatabasePrivateEndpoint: contains(overrides, 'sqlDatabasePrivateEndpoint') && !empty(overrides.sqlDatabasePrivateEndpoint) ? overrides.sqlDatabasePrivateEndpoint : defaultResourceNames.sqlDatabasePrivateEndpoint
  sqlServer: contains(overrides, 'sqlServer') && !empty(overrides.sqlServer) ? overrides.sqlServer : defaultResourceNames.sqlServer
  sqlResourceGroup: contains(overrides, 'sqlResourceGroup') && !empty(overrides.sqlResourceGroup) ? overrides.sqlResourceGroup : defaultResourceNames.sqlResourceGroup
  webAppFrontend: contains(overrides, 'webAppFrontend') && !empty(overrides.webAppFrontend) ? overrides.webAppFrontend : defaultResourceNames.webAppFrontend
  webAppService: contains(overrides, 'webAppService') && !empty(overrides.webAppService) ? overrides.webAppService : defaultResourceNames.webAppService
  webAppServicePlan: contains(overrides, 'webAppServicePlan') && !empty(overrides.webAppServicePlan) ? overrides.webAppServicePlan : defaultResourceNames.webAppServicePlan
  webApplicationFirewall: contains(overrides, 'webApplicationFirewall') && !empty(overrides.webApplicationFirewall) ? overrides.webApplicationFirewall : defaultResourceNames.webApplicationFirewall
  webAppFrontendPrivateEndpoint: contains(overrides, 'webAppFrontendPrivateEndpoint') && !empty(overrides.webAppFrontendPrivateEndpoint) ? overrides.webAppFrontendPrivateEndpoint : defaultResourceNames.webAppFrontendPrivateEndpoint
  webAppServicePrivateEndpoint: contains(overrides, 'webAppServicePrivateEndpoint') && !empty(overrides.webAppServicePrivateEndpoint) ? overrides.webAppServicePrivateEndpoint : defaultResourceNames.webAppServicePrivateEndpoint
}

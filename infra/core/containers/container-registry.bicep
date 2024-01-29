targetScope = 'resourceGroup'

/*
** Azure Container Registry
** Copyright (C) 2024 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Container Registry resource, including permission grants and diagnostics.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/ApplicationIdentity.bicep
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity.')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User.')
  principalType: 'ServicePrincipal' | 'User'
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource.')
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

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the resource group to hold the Private DNS Zone. By default, this uses the same resource group as the resource.')
  dnsResourceGroupName: string

  @description('The name of the private endpoint resource. By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint. By default, this uses the same resource group as the resource.')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

/*
** Common
*/

@description('The name of the primary resource.')
@minLength(5)
@maxLength(50)
param name string

@description('The Azure region for the resource.')
param location string = resourceGroup().location

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('Indicates whether admin user is enabled.')
param adminUserEnabled bool = false

@description('Indicates whether anonymous pull is enabled.')
param anonymousPullEnabled bool = false

@description('Specifies the SKU of the resource')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('Whether public network access is allowed for this resource. By default, public access will be enabled if no private endpoints are set. Disabling public network access requires skuName to be \'Premium\'.')
@allowed([
  'Default'
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Default'

@description('If set, the private endpoint settings for this resource.')
param privateEndpointSettings PrivateEndpointSettings?

@allowed([
  'AzureServices'
  'None'
])
@description('Whether to allow trusted Azure services to access a network restricted registry.')
param networkRuleBypassOptions string = 'AzureServices'

@description('Whether or not zone redundancy is enabled for this container registry.')
param zoneRedundancyEnabled bool = false

@description('The name of logs that will be streamed.')
@allowed([
  'allLogs'
  'ContainerRegistryRepositoryEvents'
  'ContainerRegistryLoginEvents'
])
param diagnosticLogCategoriesToEnable array = [
  'allLogs'
]

@description('The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('The list of application identities to be granted owner access to the application resources.')
param pushIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted pull access to the container registry.')
param pullIdentities ApplicationIdentity[] = []

// ========================================================================
// VARIABLES
// ========================================================================

/* https://learn.microsoft.com/azure/container-registry/container-registry-roles */

// Allows push and pull access to Azure Container Registry images.
var containerRegistryPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

// Allows pull access to Azure Container Registry images.
var containerRegistryPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    anonymousPullEnabled: anonymousPullEnabled
    networkRuleBypassOptions: networkRuleBypassOptions
    publicNetworkAccess: publicNetworkAccess != 'Default' ? publicNetworkAccess : privateEndpointSettings == null ? 'Enabled' : 'Disabled'
    zoneRedundancy: skuName == 'Premium' ? zoneRedundancyEnabled ? 'Enabled' : 'Disabled' : 'Disabled'
  }
}

resource grantPushAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in pushIdentities: if (!empty(id.principalId)) {
  name: guid(containerRegistryPushRoleId, id.principalId, containerRegistry.id, resourceGroup().name)
  scope: containerRegistry
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', containerRegistryPushRoleId)
    principalId: id.principalId
  }
}]

resource grantPullAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in pullIdentities: if (!empty(id.principalId)) {
  name: guid(containerRegistryPullRoleId, id.principalId, containerRegistry.id, resourceGroup().name)
  scope: containerRegistry
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', containerRegistryPullRoleId)
    principalId: id.principalId
  }
}]

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: containerRegistry.id
    linkServiceName: containerRegistry.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.azconfig.io'
    groupIds: [ 'registry' ]
  }
}

resource containerRegistryDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: contains(diagnosticLogCategoriesToEnable, 'allLogs') ? [
      {
        categoryGroup: 'allLogs'
        enabled: diagnosticSettings!.enableLogs
      }
    ] : map(diagnosticLogCategoriesToEnable, (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: map(diagnosticMetricsToEnable, (metric) => {
      category: metric
      enabled: diagnosticSettings!.enableMetrics
    })
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

@description('The ID of the Azure container registry.')
output id string = containerRegistry.id

@description('The Name of the Azure container registry.')
output name string = containerRegistry.name

@description('The reference to the Azure container registry.')
output loginServer string = containerRegistry.properties.loginServer

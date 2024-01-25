targetScope = 'resourceGroup'

/*
** Azure Service Bus
** Copyright (C) 2024 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Service Bus resource, including permission grants and diagnostics.
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
@minLength(6)
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

@description('Indicates whether local authentication (SAS) is enabled.')
param localAuthenticationEnabled bool = false

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

@description('Whether or not zone redundancy is enabled for this container registry.')
param zoneRedundancyEnabled bool = false

@description('The name of logs that will be streamed.')
@allowed([
  'allLogs'
  'OperationalLogs'
  'VNetAndIPFilteringLogs'
  'RuntimeAuditLogs'
  'ApplicationMetricsLogs'
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

@description('The list of application identities to be granted owner access to Service Bus data.')
param dataOwnerIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted send access to Service Bus messages.')
param dataSenderIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted read access to Service Bus messages.')
param dataReceiverIdentities ApplicationIdentity[] = []

@description('The minimum TLS version required for Service Bus.')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

// ========================================================================
// VARIABLES
// ========================================================================

/* https://learn.microsoft.com/azure/service-bus-messaging/authenticate-application */

// Allows all access to Service Bus data.
var azureServiceBusDataOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'

// Allows sending messages to Service Bus queues and topics.
var azureServiceBusDataSenderRoleRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'

// Allows getting messages from Service Bus queues and topics.
var azureServiceBusDataReceiverRoleRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess != 'Default' ? publicNetworkAccess : privateEndpointSettings == null ? 'Enabled' : 'Disabled'
    zoneRedundant: skuName == 'Premium' ? zoneRedundancyEnabled : false
    disableLocalAuth: !localAuthenticationEnabled
    minimumTlsVersion:minimumTlsVersion
    // TODO : Private endpoint settings
  }
}

resource grantDataOwnerAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in dataOwnerIdentities: if (!empty(id.principalId)) {
  name: guid(azureServiceBusDataOwnerRoleId, id.principalId, serviceBusNamespace.id, resourceGroup().name)
  scope: serviceBusNamespace
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureServiceBusDataOwnerRoleId)
    principalId: id.principalId
  }
}]

resource grantDataReceiverAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in dataReceiverIdentities: if (!empty(id.principalId)) {
  name: guid(azureServiceBusDataReceiverRoleRoleId, id.principalId, serviceBusNamespace.id, resourceGroup().name)
  scope: serviceBusNamespace
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureServiceBusDataReceiverRoleRoleId)
    principalId: id.principalId
  }
}]

resource grantDataSenderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in dataSenderIdentities: if (!empty(id.principalId)) {
  name: guid(azureServiceBusDataSenderRoleRoleId, id.principalId, serviceBusNamespace.id, resourceGroup().name)
  scope: serviceBusNamespace
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureServiceBusDataSenderRoleRoleId)
    principalId: id.principalId
  }
}]

resource serviceBusDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: serviceBusNamespace
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

@description('The ID of the Service Bus namespace.')
output id string = serviceBusNamespace.id

@description('The Service Bus namespace host endpoint.')
output endpoint string = serviceBusNamespace.properties.serviceBusEndpoint

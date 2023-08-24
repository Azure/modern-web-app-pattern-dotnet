targetScope = 'resourceGroup'

/*
** Azure Storage Account
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

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

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The name of the primary resource')
param name string

param containers array = []

@description('The tags to associate with this resource.')
param tags object = {}

param storageAccountId string = ''

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('Required for storage accounts where kind = BlobStorage. The access tier is used for billing.')
@allowed(['Cool', 'Hot', 'Premium' ])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = true

param allowCrossTenantReplication bool = true

param allowSharedKeyAccess bool = true

param deleteRetentionPolicy object = {}

param kind string = 'StorageV2'

param minimumTlsVersion string = 'TLS1_2'

param networkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

param sku object = { name: 'Standard_LRS' }

// ========================================================================
// VARIABLES
// ========================================================================

var logCategories = [
  'StorageDelete'
  'StorageRead'
  'StorageWrite'
]

var defaultToOAuthAuthentication = false
var dnsEndpointType = 'Standard'

// ========================================================================
// AZURE RESOURCES
// ========================================================================
/*
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = if (!empty(containers)) {
  properties: {
    deleteRetentionPolicy: deleteRetentionPolicy
  }
  resource container 'containers' = [for container in containers: {
    name: container.name
    properties: {
      publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
    }
  }]
}

output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
*/

output containerName string = 'tickets' // container.name

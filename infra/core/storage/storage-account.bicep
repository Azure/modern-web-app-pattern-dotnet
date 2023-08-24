targetScope = 'resourceGroup'

/*
** Azure Storage Account
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Settings
*/

@description('Required for storage accounts where kind = BlobStorage. The access tier is used for billing.')
@allowed(['Cool', 'Hot', 'Premium' ])
param accessTier string = 'Hot'

@description('Allow or disallow public access to all blobs or containers in the storage account. The default interpretation is true for this property.')
param allowBlobPublicAccess bool = true

@description('Allow or disallow cross AAD tenant object replication. The default interpretation is true for this property.')
param allowCrossTenantReplication bool = true

@description('Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param allowSharedKeyAccess bool = true

@description('Required. Indicates the type of storage account.')
@allowed(['BlobStorage', 'BlockBlobStorage', 'FileStorage', 'Storage', 'StorageV2' ])
param kind string = 'StorageV2'

param minimumTlsVersion string = 'TLS1_2'

param networkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('Required. Gets or sets the SKU name.')
param sku object = { name: 'Standard_LRS' }

// ========================================================================
// VARIABLES
// ========================================================================

var defaultToOAuthAuthentication = false
var dnsEndpointType = 'Standard'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    dnsEndpointType: dnsEndpointType
    minimumTlsVersion: minimumTlsVersion
    networkAcls: networkAcls
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  }
}

output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints

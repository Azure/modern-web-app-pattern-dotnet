targetScope = 'subscription'

/*
** Private DNS Zones
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network contains these Private DNS Zones that provide dynamic
** DNS registration for private endpoints in all virtual networks
** associated with this deployment by virtualNetworkLinks.
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The list of private DNS zones to create in this virtual network.')
param privateDnsZones array = [
  'privatelink${az.environment().suffixes.sqlServerHostname}'
  'privatelink.azconfig.io'
  'privatelink.azurecr.io'
  'privatelink.azurewebsites.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.redis.cache.windows.net'
  'privatelink.servicebus.windows.net'
  'privatelink.vaultcore.azure.net'
]

@description('The hub resource group name.')
param hubResourceGroupName string

@description('Specifies if DNS zone will be created, or if we are attaching to an existing one')
param createDnsZone bool = true

@description('Array of custom objects describing vNet links of the DNS zone. Each object should contain vnetName, vnetId, registrationEnabled')
param virtualNetworkLinks array = []

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: 'NetworkHub'
  OpsCommitment: 'Platform operations'
  ServiceClass: deploymentSettings.isProduction ? 'Gold' : 'Dev'
})

// ========================================================================
// AZURE Resources
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hubResourceGroupName
}

module createNewDnsZones '../core/network/private-dns-zone.bicep' = [ for dnsZoneName in createDnsZone ? privateDnsZones : []: {
  name: 'new-dns-zone-${deploymentSettings.resourceToken}-${dnsZoneName}'
  scope: resourceGroup
  params: {
    name: dnsZoneName
    tags: moduleTags
    virtualNetworkLinks: virtualNetworkLinks
  }
}]

module updateVnetLinkForDnsZones '../core/network/private-dns-zone-link.bicep' = [ for dnsZoneName in !createDnsZone ? privateDnsZones : []: {
  name: createDnsZone ? 'hub-dns-link-${deploymentSettings.resourceToken}-${dnsZoneName}' : 'spk-dns-link-${deploymentSettings.resourceToken}-${dnsZoneName}'
  scope: resourceGroup
  params: {
    name: dnsZoneName
    virtualNetworkLinks: virtualNetworkLinks
  }
}]

output dns_resource_group_name string = resourceGroup.name

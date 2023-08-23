targetScope = 'resourceGroup'

/*
** Private DNS Zone
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a private DNS zone (mostly used for private endpoints) and links
** it to the specified virtual network.
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the virtual network to link this DNS zone to.')
param virtualNetworkId string = ''

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
  tags: tags

  resource virtualNetworkLink 'virtualNetworkLinks' = {
    name: '${name}-link'
    location: 'global'
    tags: tags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetworkId
      }
    }
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = privateDnsZone.id
output name string = privateDnsZone.name


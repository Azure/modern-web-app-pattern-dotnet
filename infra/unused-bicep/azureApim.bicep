@description('A generated identifier used to create unique resources')
param resourceToken string

@description('Enables the template to choose different SKU by environment')
param isProd bool

@description('Name for private endpoint')
param privateEndpointNameForApim string
@description('Name of vnet for private endpoint')
param privateEndpointVnetName string
@description('Name of subnet for private endpoint')
param privateEndpointSubnetName string

@description('The Azure region name where these resources will be created')
param location string

@description('Associated tags to attach to deployed resources')
param tags object

//This parameter is required for APIM resource creation but is not being used
@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

//This parameter is required for APIM resource creation but is not being used
@description('The name of the owner of the service')
@minLength(1)
param publisherName string

var apimSkuName = isProd ? 'Standard' : 'Developer'
var apimSkuCount = 1

resource apiManagementService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: '${resourceToken}-apim'
  location: location
  tags: tags
  sku: {
    name: apimSkuName
    capacity: apimSkuCount
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource privateEndpointForApim 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: privateEndpointNameForApim
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: apiManagementService.name
        properties: {
          privateLinkServiceId: apiManagementService.id
          groupIds: [
            'Gateway'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForApim 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.apim.windows.net'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForApim_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForApim
  name: '${privateDnsZoneNameForApim.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' existing = {
  name: privateEndpointVnetName
}

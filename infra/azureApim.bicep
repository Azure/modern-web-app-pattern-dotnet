@description('A generated identifier used to create unique resources')
param resourceToken string

@description('Enables the template to choose different SKU by environment')
param isProd bool

param privateEndpointNameForApim string
param privateEndpointVnetName string
param privateEndpointSubnetName string

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

param location string
param tags object

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

var apimSkuName = isProd ? 'Standard' : 'Developer'
var apimSkuCount = isProd ? 2 : 1

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
            'apim'
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
  dependsOn: [
    vnet
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' existing = {
  name: privateEndpointVnetName
}

output privateDnsZoneId string = privateDnsZoneNameForApim.id

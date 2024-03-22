targetScope = 'subscription'

/*
** Hub Network Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network consists of a virtual network that hosts resources that
** are generally associated with a hub.
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

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for this deployment.')
param diagnosticSettings DiagnosticSettings

@description('If enabled, a Windows 11 jump host will be deployed.  Ensure you enable the bastion host as well.')
param enableJumpHost bool = false

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string = '10.0.0.0/20'

@description('If enabled, a Bastion Host will be deployed with a public IP address.')
param enableBastionHost bool = false

@description('If enabled, DDoS Protection will be enabled on the virtual network')
param enableDDoSProtection bool = true

@description('If enabled, an Azure Firewall will be deployed with a public IP address.')
param enableFirewall bool = true

@description('The address spaces allowed to connect through the firewall.  By default, we allow all RFC1918 address spaces')
param internalAddressSpace string[] = [ '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' ]

@description('The CIDR block to use for the address prefix of the primary spoke virtual network.')
param spokeAddressPrefixPrimary string

@description('The CIDR block to use for the address prefix of the secondary spoke virtual network.')
param spokeAddressPrefixSecondary string

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: 'NetworkHub'
  OpsCommitment: 'Platform operations'
  ServiceClass: deploymentSettings.isProduction ? 'Gold' : 'Dev'
})

// Allows push and pull access to Azure Container Registry images.
var containerRegistryPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

// The subnet prefixes for the individual subnets inside the virtual network
var subnetPrefixes = [ for i in range(0, 16): cidrSubnet(addressPrefix, 26, i)]

// The individual subnet definitions.
var bastionHostSubnetDefinition = {
  name: resourceNames.hubSubnetBastionHost
  properties: {
    addressPrefix: subnetPrefixes[2]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var firewallSubnetDefinition = {
  name: resourceNames.hubSubnetFirewall
  properties: {
    addressPrefix: subnetPrefixes[1]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var privateEndpointSubnet = {
  name: resourceNames.hubSubnetPrivateEndpoint
  properties: {
    addressPrefix: subnetPrefixes[0]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var subnets = union(
  [privateEndpointSubnet],
  enableBastionHost ? [bastionHostSubnetDefinition] : [],
  enableFirewall ? [firewallSubnetDefinition] : []
)

// Some helpers for the firewall rules
var allowTraffic = { type: 'allow' }
var httpProtocol  = { port: '80', protocolType: 'HTTP' }
var httpsProtocol = { port: '443', protocolType: 'HTTPS' }
var azureFqdns = loadJsonContent('./azure-fqdns.jsonc')

// The firewall application rules
var applicationRuleCollections = [
  {
    name: 'Azure-Monitor'
    properties: {
      action: allowTraffic
      priority: 201
      rules: [
        {
          name: 'allow-azure-monitor'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.azureMonitor
        }
      ]
    }
  }
  {
    name: 'Core-Dependencies'
    properties: {
      action: allowTraffic
      priority: 200
      rules: [
        {
          name: 'allow-core-apis'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.coreServices
        }
        {
          name: 'allow-developer-services'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.developerServices
        }
        {
          name: 'allow-certificate-dependencies'
          protocols: [ httpProtocol, httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.certificateServices
        }
        // Allow ACA access to managed identity services as per
        // https://learn.microsoft.com/azure/container-apps/networking?tabs=workload-profiles-env%2Cazure-cli#application-rules
        {
          name: 'allow-managed-identity-services'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.managedIdentityServices
        }
      ]
    }
  }
]

// The subnet prefixes for the individual subnets inside the virtual network
var spokeSubnetPrefixesFromPrimary = [ for i in range(0, 16): cidrSubnet(spokeAddressPrefixPrimary, 26, i)]
var spokeSubnetPrefixesFromSecondary = [ for i in range(0, 16): cidrSubnet(spokeAddressPrefixSecondary, 26, i)]

var networkRuleCollections = [
  {
    name: 'Windows-VM-Connectivity-Requirements'
    properties: {
      action: {
        type: 'allow'
      }
      priority: 202
      rules: [
        {
          destinationAddresses: [
            '20.118.99.224'
            '40.83.235.53'
            '23.102.135.246'
            '51.4.143.248'
            '23.97.0.13'
            '52.126.105.2'
          ]
          destinationPorts: [
            '*'
          ]
          name: 'allow-kms-activation'
          protocols: [
            'Any'
          ]
          sourceAddresses: deploymentSettings.isMultiLocationDeployment ? [ spokeSubnetPrefixesFromPrimary[6] ] : [ spokeSubnetPrefixesFromPrimary[6], spokeSubnetPrefixesFromSecondary[6] ]
        }
        {
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '123'
            '12000'
          ]
          name: 'allow-ntp'
          protocols: [
            'Any'
          ]
          sourceAddresses: deploymentSettings.isMultiLocationDeployment ? [ spokeSubnetPrefixesFromPrimary[6] ] : [ spokeSubnetPrefixesFromPrimary[6], spokeSubnetPrefixesFromSecondary[6] ]
        }
      ]
    }
  }
  // Allow ACA access to managed identity services as per
  // https://learn.microsoft.com/azure/container-apps/networking?tabs=workload-profiles-env%2Cazure-cli#network-rules
  {
    name: 'Identity-Services'
    properties: {
      action: {
        type: 'allow'
      }
      priority: 203
      rules: [
        {
          name: 'allow-identity-services'
          sourceAddresses: internalAddressSpace
          protocols: [
            'TCP'
          ]
          destinationAddresses: [
            'AzureActiveDirectory'
          ]
          destinationPorts: [
            '443'
          ]
        }
      ]
    }
  }
]
// Our firewall does not use NAT rule collections, but you can set them up here.
var natRuleCollections = []

// Budget amounts
//  All values are calculated in dollars (rounded to nearest dollar) in the South Central US region.
var budgetCategories = deploymentSettings.isProduction ? {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 87              /* Estimate 1GiB/day Analytics, 1GiB/day Basic Logs  */
  applicationInsights: 152      /* Estimate 5GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Basic plan, 100GiB processed */
  bastionHost: 212              /* Standard plan */
  jumphost: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
} : {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 69              /* Estimate 1GiB/day Analytics + Basic Logs  */
  applicationInsights: 187      /* Estimate 1GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Standard plan, 100GiB processed */
  bastionHost: 139              /* Basic plan */
  jumphost: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
}
var budgetAmount = reduce(map(items(budgetCategories), (obj) => obj.value), 0, (total, amount) => total + amount)

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.hubResourceGroup
}

module ddosProtectionPlan '../core/network/ddos-protection-plan.bicep' = if (enableDDoSProtection) {
  name: 'hub-ddos-protection-plan'
  scope: resourceGroup
  params: {
    name: resourceNames.hubDDoSProtectionPlan
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: 'hub-virtual-network'
  scope: resourceGroup
  params: {
    name: resourceNames.hubVirtualNetwork
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    ddosProtectionPlanId: enableDDoSProtection ? ddosProtectionPlan.outputs.id : ''
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressPrefix: addressPrefix
    diagnosticSettings: diagnosticSettings
    subnets: subnets
  }
}

module firewall '../core/network/firewall.bicep' = if (enableFirewall) {
  name: 'hub-firewall'
  scope: resourceGroup
  params: {
    name: resourceNames.hubFirewall
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetFirewall].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubFirewallPublicIpAddress
    sku: 'Standard'
    threatIntelMode: 'Deny'
    zoneRedundant: deploymentSettings.isProduction

    // Firewall rules
    applicationRuleCollections: applicationRuleCollections
    natRuleCollections: natRuleCollections
    networkRuleCollections: networkRuleCollections
  }
}


module bastionHost '../core/network/bastion-host.bicep' = if (enableBastionHost) {
  name: 'hub-bastion-host'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBastionHost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetBastionHost].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubBastionPublicIpAddress
    sku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    zoneRedundant: deploymentSettings.isProduction
  }
}

/*
  The vault will always be deployed because it stores Microsoft Entra app registration details.
  The dynamic part of this feature is whether or not the Vault is located in the Hub (yes, when Network Isolated)
  or if it is located in the Workload resource group (yes, when Network Isolation is not enabled).
 */
module sharedKeyVault '../core/security/key-vault.bicep' = {
  name: 'shared-key-vault'
  scope: resourceGroup

  dependsOn: [
    // Provisioning the Key Vault involves creating a private endpoint, which requires
    // private DNS zones to be created and linked to the virtual network.
    privateDnsZones
  ]

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
    ]
    privateEndpointSettings: {
      dnsResourceGroupName: resourceGroup.name
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceGroup.name
      subnetId: virtualNetwork.outputs.subnets[privateEndpointSubnet.name].id
    }
  }
}

/*
** Azure Container Registry
** The registry is deployed with the hub in production scenarios but with application resources in dev scenarios.
*/

module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.0' = {
  name: 'shared-application-container-registry'
  scope: resourceGroup

  dependsOn: [
    // Provisioning the Container Registry involves creating a private endpoint, which requires
    // private DNS zones to be created and linked to the virtual network.
    privateDnsZones
  ]

  params: {
    name: resourceNames.containerRegistry
    location: deploymentSettings.location
    tags: moduleTags
    acrSku: (deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated) ? 'Premium' :  'Basic'

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
    publicNetworkAccess: (deploymentSettings.isProduction && deploymentSettings.isNetworkIsolated) ? 'Disabled' : 'Enabled'
    privateEndpoints: deploymentSettings.isNetworkIsolated ? [
      {
        privateDnsZoneGroupName: resourceGroup.name
        privateDnsZoneResourceIds: [
          resourceId(subscription().subscriptionId, resourceGroup.name, 'Microsoft.Network/privateDnsZones', 'privatelink.azurecr.io')
        ]
        subnetResourceId: virtualNetwork.outputs.subnets[privateEndpointSubnet.name].id
        tags: moduleTags
      }
    ] : null
    replications: deploymentSettings.isMultiLocationDeployment ? [
      // The primary region doesn't need to be listed in replicas. It will be deployed automatically.
      // Replications only needs to list secondary regions.
      {
        location: deploymentSettings.secondaryLocation
        name: deploymentSettings.secondaryLocation
      }
    ] : null
    roleAssignments: [
      {
        principalId: deploymentSettings.principalId
        principalType: deploymentSettings.principalType
        roleDefinitionIdOrName: containerRegistryPushRoleId
      }
    ]
  }
}

module hubBudget '../core/cost-management/budget.bicep' = {
  name: 'hub-budget'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBudget
    amount: budgetAmount
    contactEmails: [
      deploymentSettings.tags['azd-owner-email']
    ]
    resourceGroups: [
      resourceGroup.name
    ]
  }
}

var virtualNetworkLinks = [
  {
    vnetName: virtualNetwork.outputs.name
    vnetId: virtualNetwork.outputs.id
    registrationEnabled: false
  }
]

module privateDnsZones './private-dns-zones.bicep' = {
  name: 'hub-private-dns-zone-deploy'
  params:{
    deploymentSettings: deploymentSettings
    hubResourceGroupName: resourceGroup.name
    virtualNetworkLinks: virtualNetworkLinks
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output bastion_hostname string = enableBastionHost ? bastionHost.outputs.hostname : ''
output firewall_hostname string = enableFirewall ? firewall.outputs.hostname : ''
output firewall_ip_address string = enableFirewall ? firewall.outputs.internal_ip_address : ''
output virtual_network_id string = virtualNetwork.outputs.id
output virtual_network_name string = virtualNetwork.outputs.name
output key_vault_name string = enableJumpHost ? sharedKeyVault.outputs.name : ''
output container_registry_name string = containerRegistry.outputs.name

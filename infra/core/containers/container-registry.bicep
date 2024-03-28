targetScope = 'resourceGroup'

/*
** Azure Container Registry
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Container Registry resource, including permission grants and diagnostics.
*/


// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the resource group to hold the Private DNS Zone. By default, this uses the same resource group as the resource.')
  dnsResourceGroupName: string

  @description('The name of the private endpoint resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint.')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}

// From: https://github.com/Azure/bicep-registry-modules/blob/main/avm/res/container-registry/registry/main.bicep
type roleAssignmentType = {
  @description('Required. The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitionIdOrName: string

  @description('Required. The principal ID of the principal (user/group/identity) to assign the role to.')
  principalId: string

  @description('Optional. The principal type of the assigned principal ID.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ForeignGroup' | 'Device')?

  @description('Optional. The description of the role assignment.')
  description: string?

  @description('Optional. The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container".')
  condition: string?

  @description('Optional. Version of the condition.')
  conditionVersion: '2.0'?

  @description('Optional. The Resource Id of the delegated managed identity resource.')
  delegatedManagedIdentityResourceId: string?
}[]?

// ========================================================================
// PARAMETERS
// ========================================================================

@description('Required. Name of your Azure Container Registry.')
@minLength(5)
@maxLength(46)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

/*
** Settings
*/

@description('Optional. Tier of your Azure container registry.')
@allowed([
  'Basic'
  'Premium'
  'Standard'
])
param acrSku string = 'Basic'

@description('Optional. Enable admin user that have push / pull permission to the registry.')
param acrAdminUserEnabled bool = false

@description('Optional. Enables registry-wide pull from unauthenticated clients. It\'s in preview and available in the Standard and Premium service tiers.')
param anonymousPullEnabled bool = false

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. The value that indicates whether the policy for using ARM audience token for a container registr is enabled or not. Default is enabled.')
param azureADAuthenticationAsArmPolicyStatus string = 'enabled'

@description('Optional. Enable a single data endpoint per region for serving data. Not relevant in case of disabled public access. Note, requires the \'acrSku\' to be \'Premium\'.')
param dataEndpointEnabled bool = false

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. The value that indicates whether the export policy is enabled or not.')
param exportPolicyStatus string = 'disabled'

@allowed([
  'AzureServices'
  'None'
])
@description('Optional. Whether to allow trusted Azure services to access a network restricted registry.')
param networkRuleBypassOptions string = 'AzureServices'

@allowed([
  'Allow'
  'Deny'
])
@description('Optional. The default action of allow or deny when no other rules match.')
param networkRuleSetDefaultAction string = 'Deny'

@description('Optional. The IP ACL rules. Note, requires the \'acrSku\' to be \'Premium\'.')
param networkRuleSetIpRules array?

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('Optional. Whether or not public network access is allowed for this resource. For security reasons it should be disabled. If not specified, it will be disabled by default if private endpoints are set and networkRuleSetIpRules are not set.  Note, requires the \'acrSku\' to be \'Premium\'.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string?

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. The value that indicates whether the quarantine policy is enabled or not.')
param quarantinePolicyStatus string = 'disabled'

@description('Optional. All replications to create.')
param replications array?

@description('Optional. The number of days to retain an untagged manifest after which it gets purged.')
param retentionPolicyDays int = 15

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. The value that indicates whether the retention policy is enabled or not.')
param retentionPolicyStatus string = 'enabled'

@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType

@description('Optional. The number of days after which a soft-deleted item is permanently deleted.')
param softDeletePolicyDays int = 7

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. Soft Delete policy status. Default is disabled.')
param softDeletePolicyStatus string = 'disabled'

@allowed([
  'disabled'
  'enabled'
])
@description('Optional. The value that indicates whether the trust policy is enabled or not.')
param trustPolicyStatus string = 'disabled'

@description('Optional. Tags of the resource.')
param tags object?

@allowed([
  'Disabled'
  'Enabled'
])
@description('Optional. Whether or not zone redundancy is enabled for this container registry.')
param zoneRedundancy string = 'Disabled'

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

// ========================================================================
// VARIABLES
// ========================================================================

var builtInRoleNames = {
  AcrDelete: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'c2f4ef07-c644-48eb-af81-4b1b4947fb11')
  AcrImageSigner: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '6cef56e8-d556-48e5-a04f-b8e64114680f'
  )
  AcrPull: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  AcrPush: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
  AcrQuarantineReader: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'cdda3590-29a3-44f6-95f2-9f980659eb04'
  )
  AcrQuarantineWriter: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'c8d4ff99-41c3-41a8-9f60-21dfdad59608'
  )
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator (Preview)': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
  )
  'User Access Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
  )
}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource registry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    anonymousPullEnabled: anonymousPullEnabled
    adminUserEnabled: acrAdminUserEnabled
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: azureADAuthenticationAsArmPolicyStatus
      }
      exportPolicy: acrSku == 'Premium'
        ? {
            status: exportPolicyStatus
          }
        : null
      quarantinePolicy: {
        status: quarantinePolicyStatus
      }
      trustPolicy: {
        type: 'Notary'
        status: trustPolicyStatus
      }
      retentionPolicy: acrSku == 'Premium'
        ? {
            days: retentionPolicyDays
            status: retentionPolicyStatus
          }
        : null
      softDeletePolicy: {
        retentionDays: softDeletePolicyDays
        status: softDeletePolicyStatus
      }
    }
    dataEndpointEnabled: dataEndpointEnabled
    publicNetworkAccess: !empty(publicNetworkAccess)
      ? any(publicNetworkAccess)
      : (privateEndpointSettings != null && empty(networkRuleSetIpRules) ? 'Disabled' : null)
    networkRuleBypassOptions: networkRuleBypassOptions
    networkRuleSet: !empty(networkRuleSetIpRules)
      ? {
          defaultAction: networkRuleSetDefaultAction
          ipRules: networkRuleSetIpRules
        }
      : null
    zoneRedundancy: acrSku == 'Premium' ? zoneRedundancy : null
  }
}

resource registry_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (roleAssignment, index) in (roleAssignments ?? []): {
    name: guid(registry.id, roleAssignment.principalId, roleAssignment.roleDefinitionIdOrName)
    properties: {
      roleDefinitionId: contains(builtInRoleNames, roleAssignment.roleDefinitionIdOrName)
        ? builtInRoleNames[roleAssignment.roleDefinitionIdOrName]
        : contains(roleAssignment.roleDefinitionIdOrName, '/providers/Microsoft.Authorization/roleDefinitions/')
            ? roleAssignment.roleDefinitionIdOrName
            : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName)
      principalId: roleAssignment.principalId
      description: roleAssignment.?description
      principalType: roleAssignment.?principalType
      condition: roleAssignment.?condition
      conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
      delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
    }
    scope: registry
  }
]

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: registry.id
    linkServiceName: registry.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.azurecr.io'
    groupIds: [ 'registry' ]
  }
  dependsOn: [ registry_replications ]
}

module registry_replications 'container-registry-replication.bicep' = [
  for (replication, index) in (replications ?? []): {
    name: '${uniqueString(deployment().name, location)}-Registry-Replication-${index}'
    params: {
      name: replication.name
      registryName: registry.name
      location: replication.location
      regionEndpointEnabled: replication.?regionEndpointEnabled
      zoneRedundancy: replication.?zoneRedundancy
      tags: replication.?tags ?? tags
    }
  }
]


resource registry_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnosticSettings-${name}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [{ category: 'AllMetrics', enabled: true }]
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    logAnalyticsDestinationType: 'AzureDiagnostics'
  }
  scope: registry
}

// ========================================================================
// OUTPUTS
// ========================================================================

output name string = registry.name
output loginServer string = registry.properties.loginServer

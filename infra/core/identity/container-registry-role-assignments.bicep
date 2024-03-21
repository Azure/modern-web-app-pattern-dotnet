targetScope = 'resourceGroup'

/*
** Azure Container Registry Role Assignments
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Assigns roles to an Azure Container Registry for the specified identities.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/ApplicationIdentity.bicep
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User')
  principalType: 'ServicePrincipal' | 'User'
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the Azure Container Registry to add role assignments for.')
param name string

@description('The list of application identities to be granted push access to the Azure Container Registry.')
param pushIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted pull access to the Azure Container Registry.')
param pullIdentities ApplicationIdentity[] = []

// ========================================================================
// VARIABLES
// ========================================================================

// Allows push and pull access to Azure Container Registry images.
var containerRegistryPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

// Allows pull access to Azure Container Registry images.
var containerRegistryPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource registry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
  name: name
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in pushIdentities: if (!empty(id.principalId)) {
  name: guid(containerRegistryPushRoleId, id.principalId, registry.id, resourceGroup().name)
  scope: registry
  properties: {
    roleDefinitionId: containerRegistryPushRoleId
    principalId: id.principalId
    principalType: id.principalType
  }
}]

resource appRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in pullIdentities: if (!empty(id.principalId)) {
  name: guid(containerRegistryPullRoleId, id.principalId, registry.id, resourceGroup().name)
  scope: registry
  properties: {
    roleDefinitionId: containerRegistryPullRoleId
    principalId: id.principalId
    principalType: id.principalType
  }
}]

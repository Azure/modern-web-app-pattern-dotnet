targetScope = 'resourceGroup'

/*
** A Container App running on a pre-existing Managed Environment (ACA Environment)
** Copyright (C) 2024 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// This simple ACA module is used until an updated Azure Verified Module
// is available using the new Container Apps API (version 2024-02-02-preview or newer).

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// https://learn.microsoft.com/rest/api/containerapps/container-apps/get?view=rest-containerapps-2024-03-01&tabs=HTTP#container
type container = {
  @description('Container start command arguments.')
  args: string[]?

  @description('Container start command.')
  command: string[]?

  @description('Container environment variables.')
  env: environmentVar[]?

  @description('Container image tag.')
  image: string

  @description('Custom container name.')
  name: string?

  @description('List of health probes for the container.')
  probes: object[]?

  @description('Container resource requirements.')
  resources: object

  @description('Container volume mounts.')
  volumeMounts: volumeMount[]?
}

// https://learn.microsoft.com/rest/api/containerapps/container-apps/get?view=rest-containerapps-2024-03-01&tabs=HTTP#environmentvar
type environmentVar = {
  @description('Environment variable name.')
  name: string

  @description('Name of the Container App secret from which to pull the environment variable value.')
  secretRef: string?

  @description('Non-secret environment variable value.')
  value: string?
}

// https://learn.microsoft.com/rest/api/containerapps/container-apps/get?view=rest-containerapps-2024-03-01&tabs=HTTP#volumemount
type volumeMount = {
  @description('Path within the container where the volume should be mounted. Must not contain \':\'.')
  mountPath: string

  @description('Path within the volume from which the container\'s volume should be mounted. Defaults to "" (volume\'s root).')
  subPath: string?

  @description('This must match the Name of a Volume.')
  volumeName: string
}

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
** Dependencies
*/
@description('The resource ID of the hosting Azure Container managed environment.')
param environmentId string

@description('The ID of a user-assigned managed identity to use as the identity for this resource.  Use a blank string for a system-assigned identity.')
param managedIdentityId string = ''

/*
** Settings
*/

@description('Container images included in the container app.')
param containers container[]

@description('If true, allow HTTP connections to the container app endpoint. If false, HTTP connections are redirected to HTTPS.')
param ingressAllowInsecure bool = false

@description('If true, allow external access to the container app endpoint.')
param ingressExternal bool = false

@description('Container port for ingress traffic.')
param ingressTargetPort int = 80

@description('Credentials for private container registries. Entries defined with secretref reference the secrets configuration object.')
param registries array = []

@description('Scale rule maximum replica count.')
param scaleMaxReplicas int = 5

@description('Scale rule minimum replica count.')
param scaleMinReplicas int = 1

@description('Scale rules for the container app.')
param scaleRules array = []

@description('Workload profile to use for app execution.')
param workloadProfileName string = ''

// ========================================================================
// VARIABLES
// ========================================================================

var identity = !empty(managedIdentityId) ? {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityId}': {}
  }
} : {
  type: 'SystemAssigned'
}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource containerApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: identity

  properties: {
    environmentId: environmentId
    workloadProfileName: workloadProfileName
    configuration: {
      ingress: {
        external: ingressExternal
        targetPort: ingressTargetPort
        allowInsecure: ingressAllowInsecure
      }
      registries: !empty(registries) ? registries : null
    }
    template: {
      containers: containers
      scale: {
        minReplicas: scaleMinReplicas
        maxReplicas: scaleMaxReplicas
        rules: !empty(scaleRules) ? scaleRules : null
      }
    }
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = containerApp.id
output name string = containerApp.name

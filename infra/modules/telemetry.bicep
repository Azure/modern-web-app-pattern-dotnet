targetScope = 'subscription'

/*
** An App Service running on a App Service Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

  @description('The primary Azure region to host resources')
  location: string

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

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The name of the workload resource group')
param resourceGroupName string

// ========================================================================
// VARIABLES
// ========================================================================

var telemetryId = '2e1b35cf-c556-45fd-87d5-bfc08ac2e8ba'

// location replace with differentiator
// resource group name
// add telemetry for workload name
// - capture deployment parameters for workload
// test if deployment is deleted per group

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource telemetrySubscription 'Microsoft.Resources/deployments@2021-04-01' = {
  name: '${telemetryId}-${deploymentSettings.location}'
  location: deploymentSettings.location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: {}
    }
  }
}

resource telemetryResourceGroup 'Microsoft.Resources/deployments@2021-04-01' = {
  name: '${telemetryId}-${deploymentSettings.workloadTags.WorkloadName}'
  resourceGroup: resourceGroupName
  tags:{
    isNetworkIsolated: deploymentSettings.isNetworkIsolated ? 'true' : 'false'
    isProduction: deploymentSettings.isProduction ? 'true' : 'false'
    location: deploymentSettings.location
    name: deploymentSettings.name
    principalType: deploymentSettings.principalType
    stage: deploymentSettings.stage
  }
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: {}
    }
  }
}

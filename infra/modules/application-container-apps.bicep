targetScope = 'resourceGroup'

/*
** An Azure Container App Environment with container apps necessary to
** run Relecloud workloads.
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The name of the App Configuration store to use for configuration.')
param appConfigurationName string

@description('The container registry server to use for the container image.')
param containerRegistryLoginServer string

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string

@description('The managed identity to use as the identity of the Container Apps.')
param managedIdentityName string

@description('The name of the Service Bus namespace for ticket render requests which will be used to trigger scaling.')
param renderRequestServiceBusNamespace string

@description('The name of the Service Bus queue for ticket render requests which will be used to trigger scaling.')
param renderRequestServiceBusQueueName string

/*
** Settings
*/
@description('Name of the Container Apps managed environment')
param containerAppEnvironmentName string

@description('Name of the Container App hosting the ticket rendering service')
param renderingServiceContainerAppName string

@description('In network isolated deployments, this specifies the subnet to use for the Container Apps managed environment infrastructure.')
param subnetId string?

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appConfigurationStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.2' = {
  name: 'application-container-apps-environment'
  scope: resourceGroup()
  params: {
    // Required and common parameters
    name: containerAppEnvironmentName
    location: deploymentSettings.location
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
    tags: tags

    // Settings
    infrastructureSubnetId: subnetId
    internal: deploymentSettings.isNetworkIsolated
    zoneRedundant: deploymentSettings.isProduction

    workloadProfiles: [
      {
        // https://learn.microsoft.com/azure/container-apps/workload-profiles-overview#profile-types
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

module renderingServiceContainerApp 'br/public:avm/res/app/container-app:0.1.0' = {
  name: 'application-rendering-service-container-app'
  scope: resourceGroup()
  params: {
    name: renderingServiceContainerAppName
    environmentId: containerAppsEnvironment.outputs.resourceId
    location: deploymentSettings.location
    tags: union(tags, {'azd-service-name': 'rendering-service'})

    // Will be added during deployment
    containers: [
      {
        name: 'rendering-service'

        // A container image is required to deploy the ACA resource.
        // Since the rendering service image is not available yet,
        // we use a placeholder image for now.
        image: 'mcr.microsoft.com/k8se/quickstart:latest'

        probes: [
          {
            type: 'liveness'
            httpGet: {
              path: '/health'
              port: 8080
            }
            initialDelaySeconds: 2
            periodSeconds: 10
          }
        ]

        env: [
          {
            name: 'App__AppConfig__Uri'
            value: appConfigurationStore.properties.endpoint
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: managedIdentity.properties.clientId
          }
          {
            name: 'App__AzureCredentialType'
            value: 'ManagedIdentity'
          }
        ]

        resources: {
          // Workaround bicep not supporting floating point numbers
          // Related issue: https://github.com/Azure/bicep/issues/1386
          cpu: json('0.25')
          memory: '0.5Gi'
        }
      }
    ]

    // Setting ingressExternal to true will create an endpoint for the container app,
    // but it will still be available only within the vnet if the managed environment
    // has internal set to true.
    ingressExternal: true
    ingressAllowInsecure: false
    ingressTargetPort: 8080

    managedIdentities: {
      userAssignedResourceIds: [
        managedIdentity.id
      ]
    }

    registries: [
      {
        server: containerRegistryLoginServer
        identity: managedIdentity.id
      }
    ]

    secrets: {
      secureList: [
        // Key Vault secrets are not populated yet when this template is deployed.
        // Therefore, no secrets are added at this time. Instead, they are added
        // by the pre-deployment 'call-configure-aca-secrets' that is executed
        // as part of `azd deploy`.
      ]
    }

    scaleRules: [
      {
        name: 'service-bus-queue-length-rule'
        custom: {
          type: 'azure-servicebus'
          metadata: {
            messageCount: '10'
            namespace: renderRequestServiceBusNamespace
            queueName: renderRequestServiceBusQueueName
          }
          auth: [
            {
              secretRef: 'render-request-queue-connection-string'
              triggerParameter: 'connection'
            }
          ]
        }
      }
    ]
    scaleMaxReplicas: 5
    scaleMinReplicas: 0

    workloadProfileName: 'Consumption'
  }
}

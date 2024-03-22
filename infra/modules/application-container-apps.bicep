targetScope = 'resourceGroup'

/*
** An Azure Container App Environment with container apps necessary to
** run Relecloud workloads.
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

  @description('The token to use for naming resources.  This should be unique to the deployment.')
  resourceToken: string

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

@description('The name of the Key Vault to use for secrets.')
param keyVaultName string

@description('The name of the resource group containing the Key Vault.')
param keyVaultResourceGroupName string

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
// VARIABLES
// ========================================================================

// True if deploying into the primary region in a multi-region deployment, otherwise false
var isPrimaryLocation = deploymentSettings.location == deploymentSettings.primaryLocation

// The name of the secret in the Key Vault containing the Service Bus connection string
var serviceBusConnectionStringSecretName = 'App--RenderRequestQueue--ConnectionString--${isPrimaryLocation? 'Primary' : 'Secondary'}'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appConfigurationStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroupName)
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

targetScope = 'subscription'

/*
** Application Infrastructure post-configuration
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Application consists of a virtual network that has shared resources that
** are generally associated with a hub. This module provides post-configuration
** actions such as creating key-vault secrets to save information from
** modules that depend on the hub.
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

/*
** Dependencies
*/
@description('The resource names for the resources to be created.')
param keyVaultName string

@description('Name of the hub resource group containing the key vault.')
param kvResourceGroupName string

@description('Name of the primary resource group containing application resources such as Azure Cache for Redis and Azure Service Bus.')
param applicationResourceGroupNamePrimary string

@description('Name of the secondary resource group containing application resources such as Azure Cache for Redis and Azure Service Bus.')
param applicationResourceGroupNameSecondary string

@description('Name of the primary Service Bus namespace.')
param serviceBusNamespacePrimary string

@description('Name of the secondary Service Bus namespace.')
param serviceBusNamespaceSecondary string

@description('List of user assigned managed identities that will receive Secrets User role to the shared key vault')
param readerIdentities object[]

// ========================================================================
// VARIABLES
// ========================================================================

var microsoftEntraIdApiClientId = 'Api--MicrosoftEntraId--ClientId'
var microsoftEntraIdApiInstance = 'Api--MicrosoftEntraId--Instance'
var microsoftEntraIdApiScope = 'App--RelecloudApi--AttendeeScope'
var microsoftEntraIdApiTenantId = 'Api--MicrosoftEntraId--TenantId'
var microsoftEntraIdCallbackPath = 'MicrosoftEntraId--CallbackPath'
var microsoftEntraIdClientId = 'MicrosoftEntraId--ClientId'
var microsoftEntraIdClientSecret = 'MicrosoftEntraId--ClientSecret'
var microsoftEntraIdInstance = 'MicrosoftEntraId--Instance'
var microsoftEntraIdSignedOutCallbackPath = 'MicrosoftEntraId--SignedOutCallbackPath'
var microsoftEntraIdTenantId = 'MicrosoftEntraId--TenantId'
var serviceBusConnectionStringPrimary = 'App--RenderRequestQueue--ConnectionString--Primary'
var serviceBusConnectionStringSecondary = 'App--RenderRequestQueue--ConnectionString--Secondary'

var multiRegionalSecrets = deploymentSettings.isMultiLocationDeployment ? [serviceBusConnectionStringSecondary] : []

var listOfAppConfigSecrets = [
  microsoftEntraIdApiClientId
  microsoftEntraIdApiInstance
  microsoftEntraIdApiScope
  microsoftEntraIdApiTenantId
  microsoftEntraIdCallbackPath
  microsoftEntraIdClientId
  microsoftEntraIdClientSecret
  microsoftEntraIdInstance
  microsoftEntraIdSignedOutCallbackPath
  microsoftEntraIdTenantId
]

var listOfSecretNames = union(listOfAppConfigSecrets,
  [
    serviceBusConnectionStringPrimary
  ], multiRegionalSecrets)
// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource existingKvResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: kvResourceGroupName
}

resource existingPrimaryServiceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespacePrimary
  scope: resourceGroup(applicationResourceGroupNamePrimary)
}

resource existingSecondaryServiceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = if (deploymentSettings.isMultiLocationDeployment) {
  name: serviceBusNamespaceSecondary
  scope: resourceGroup(applicationResourceGroupNameSecondary)
}

resource existingPrimaryRenderRequestQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' existing = {
  name: 'ticket-render-requests'
  parent: existingPrimaryServiceBusNamespace
}

resource existingSecondaryRenderRequestQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' existing = if (deploymentSettings.isMultiLocationDeployment) {
  name: 'ticket-render-requests'
  parent: existingSecondaryServiceBusNamespace
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: existingKvResourceGroup
}

// ========================================================================
// AZURE MODULES
// ========================================================================

module writePrimaryRenderQueueConnectionString '../core/security/key-vault-secrets.bicep' = {
  name: 'write-primary-render-queue-connection-string-${deploymentSettings.resourceToken}'
  scope: existingKvResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: serviceBusConnectionStringPrimary, value: listKeys('${existingPrimaryRenderRequestQueue.id}/AuthorizationRules/manage-render-queue-policy', existingPrimaryRenderRequestQueue.apiVersion).primaryConnectionString }
    ]
  }
}

module writeSecondaryRenderQueueConnectionString '../core/security/key-vault-secrets.bicep' = if (deploymentSettings.isMultiLocationDeployment) {
  name: 'write-secondary-render-queue-connection-string-${deploymentSettings.resourceToken}'
  scope: existingKvResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: serviceBusConnectionStringSecondary, value: listKeys('${existingSecondaryRenderRequestQueue.id}/AuthorizationRules/manage-render-queue-policy', existingSecondaryRenderRequestQueue.apiVersion).primaryConnectionString }
    ]
  }
}

// ======================================================================== //
// Microsoft Entra Application Registration placeholders
// ======================================================================== //
module writeAppRegistrationSecrets '../core/security/key-vault-secrets.bicep' = [ for (secretName, index) in listOfAppConfigSecrets: {
  name: 'temp-kv-secret-${index}-${deploymentSettings.resourceToken}'
  scope: existingKvResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: secretName, value: 'placeholder-populated-by-script' }
    ]
  }
}]

// ======================================================================== //
// Grant reader permissions for the web apps to access the key vault
// ======================================================================== //

module grantSecretsUserAccessBySecretName './grant-secret-user.bicep' = [ for (secretName, index) in listOfSecretNames: {
  scope: existingKvResourceGroup
  name: 'grant-kv-access-for-${index}-${deploymentSettings.resourceToken}'
  params: {
    keyVaultName: existingKeyVault.name
    readerIdentities: readerIdentities
    secretName: secretName
  }
  dependsOn: [
    writeAppRegistrationSecrets
  ]
}]

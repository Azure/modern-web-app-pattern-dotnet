targetScope = 'subscription'

/*
** Hub Network Infrastructure post-configuration
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network consists of a virtual network that hosts resources that
** are generally associated with a hub. This module provides post-configuration
** actions such as creating key-vault secrets to save information from
** modules that depend on the hub.
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
  
  @description('If \'false\', then this is a multi-location deployment for the second location.')
  isPrimaryLocation: bool

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

/*
** Passwords - specify these!
*/
@secure()
@minLength(12)
@description('The password for the administrator account.  This will be used for the jump host, SQL server, and anywhere else a password is needed for creating a resource.')
param administratorPassword string = newGuid()

@minLength(8)
@description('The username for the administrator account on the jump host.')
param administratorUsername string = 'adminuser'

@secure()
@minLength(8)
@description('The password for the administrator account on the SQL Server.')
param databasePassword string

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The resource names for the resources to be created.')
param keyVaultName string

@description('Name of the hub resource group.')
param hubResourceGroupName string

@description('Name of the resource group containing Azure Cache for Redis.')
param redisCacheName string

@description('Name of the resource group containing Azure Cache for Redis.')
param workloadResourceGroupNamePrimary string

@description('Name of the resource group containing Azure Cache for Redis.')
param workloadResourceGroupNameSecondary string

@description('List of user assigned managed identities that will receive Secrets User role to the shared key vault')
param readerIdentities object[]

// ========================================================================
// VARIABLES
// ========================================================================

var redisCacheSecretNamePrimary = 'App--RedisCache--ConnectionString-Primary'
var redisCacheSecretNameSecondary = 'App--RedisCache--ConnectionString-Secondary'
var azureAdClientSecret = 'AzureAd--ClientSecret'

var multiRegionalSecrets = deploymentSettings.isMultiLocationDeployment ? [redisCacheSecretNameSecondary] : []

var listOfSecretNames = union([
    redisCacheSecretNamePrimary
    azureAdClientSecret
  ], multiRegionalSecrets)

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource existingHubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hubResourceGroupName
}

resource existingPrimaryRedisCache 'Microsoft.Cache/redis@2023-04-01' existing = {
  name: redisCacheName
  scope: resourceGroup(workloadResourceGroupNamePrimary)
}

resource existingSecondaryRediscache 'Microsoft.Cache/redis@2023-04-01' existing = if (deploymentSettings.isMultiLocationDeployment) {
  name: redisCacheName
  scope: resourceGroup(deploymentSettings.isMultiLocationDeployment ? workloadResourceGroupNameSecondary : workloadResourceGroupNamePrimary)
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: existingHubResourceGroup
}

// ========================================================================
// AZURE MODULES
// ========================================================================

module writeJumpHostCredentialsToKeyVault '../core/security/key-vault-secrets.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'hub-write-jumphost-credentials'
  scope: existingHubResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: 'Jumphost--AdministratorPassword', value: administratorPassword          }
      { key: 'Jumphost--AdministratorUsername', value: administratorUsername          }
      { key: 'Jumphost--ComputerName',          value: resourceNames.hubJumphost }
    ]
  }
}

module writeSqlAdminInfoToKeyVault '../core/security/key-vault-secrets.bicep' = {
  name: 'write-sql-admin-info-to-keyvault'
  scope: existingHubResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: 'Relecloud--SqlAdministratorUsername', value: administratorUsername }
      { key: 'Relecloud--SqlAdministratorPassword', value: databasePassword }
    ]
  }
}

module writePrimaryRedisSecret '../core/security/key-vault-secrets.bicep' = {
  name: 'write-primary-redis-secret-to-keyvault'
  scope: existingHubResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: redisCacheSecretNamePrimary, value: '${existingPrimaryRedisCache.name}.redis.cache.windows.net:6380,password=${existingPrimaryRedisCache.listKeys().primaryKey},ssl=True,abortConnect=False' }
    ]
  }
}

module writeSecondaryRedisSecret '../core/security/key-vault-secrets.bicep' = if (deploymentSettings.isMultiLocationDeployment) {
  name: 'write-secondary-redis-secret-to-keyvault'
  scope: existingHubResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: redisCacheSecretNameSecondary, value: '${existingSecondaryRediscache.name}.redis.cache.windows.net:6380,password=${existingSecondaryRediscache.listKeys().primaryKey},ssl=True,abortConnect=False' }
    ]
  }
}

// ======================================================================== //
// Azure AD Application Registration placeholders
// ======================================================================== //

module writeSecondaryAppRegistrationSecrets '../core/security/key-vault-secrets.bicep' = {
  name: 'write-app-registration-secrets-to-keyvault'
  scope: existingHubResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: azureAdClientSecret, value: 'placeholder-populated-by-script' }
    ]
  }
}

// ======================================================================== //
// Grant reader permissions for the web apps to access the key vault
// ======================================================================== //

module grantSecretsUserAccessBySecretName './grant-secret-user.bicep' = [ for secretName in listOfSecretNames: {
  scope: existingHubResourceGroup
  name: 'grant-kv-access-for-${secretName}'
  params: {
    keyVaultName: existingKeyVault.name
    readerIdentities: readerIdentities
    secretName: secretName
  }
}]

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
param workloadResourceGroupName string

// ========================================================================
// VARIABLES
// ========================================================================

var redisConnectionSecretName='App--RedisCache--ConnectionString'

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hubResourceGroupName
}

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: workloadResourceGroupName
}

resource cache 'Microsoft.Cache/redis@2023-04-01' existing = {
  name: redisCacheName
  scope: workloadResourceGroup
}

// ========================================================================
// AZURE MODULES
// ========================================================================

module writeJumpHostCredentialsToKeyVault '../core/security/key-vault-secrets.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'hub-write-jumphost-credentials'
  scope: hubResourceGroup
  params: {
    name: keyVaultName
    secrets: [
      { key: 'Jumphost--AdministratorPassword', value: administratorPassword          }
      { key: 'Jumphost--AdministratorUsername', value: administratorUsername          }
      { key: 'Jumphost--ComputerName',          value: resourceNames.hubJumphost }
    ]
  }
}

module writeSqlAdminInfoToKeyVault '../core/security/key-vault-secrets.bicep' = {
  name: 'write-sql-admin-info-to-keyvault'
  scope: hubResourceGroup
  params: {
    name: keyVaultName
    secrets: [
      { key: 'Relecloud--SqlAdministratorUsername', value: administratorUsername }
      { key: 'Relecloud--SqlAdministratorPassword', value: databasePassword }
    ]
  }
}

module writeRedisSecret '../core/security/key-vault-secrets.bicep' = {
  name: 'write-redis-secret-to-keyvault'
  scope: hubResourceGroup
  params: {
    name: keyVaultName
    secrets: [
      { key: redisConnectionSecretName, value: '${cache.name}.redis.cache.windows.net:6380,password=${cache.listKeys().primaryKey},ssl=True,abortConnect=False' }
    ]
  }
}

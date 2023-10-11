targetScope = 'resourceGroup'

/*
** Write key vault references to App Configuration Store
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Writes a set of key values to the connected App Configuration store.
** Requires that the App Configuration store be public network enabled.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

@description('The form of each App Configuration key value to store.')
type AppConfigurationKeyValues = {
  @description('The key for the config value')
  key: string

  @description('The value of the config value')
  value: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the Key Vault resource')
param name string

/*
** Settings
*/
@description('The list of secrets to store in the Key Vault')
param keyvalues AppConfigurationKeyValues[]

@description('Required when setting a configuration that references key vault.')
param keyvaultname string = ''

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: name
}
resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyvaultname
}

resource keyValuePairs 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for keyvalue in keyvalues: {
  name: keyvalue.key
  parent: appConfiguration
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    value: string({
      uri: '${existingKeyVault.properties.vaultUri}secrets/${keyvalue.value}'
    })
  }
}]

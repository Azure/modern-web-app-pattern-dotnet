targetScope = 'resourceGroup'

/*
** Write configuration to App Configuration Store
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

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: name
}

resource keyValuePairs 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for keyvalue in keyvalues: {
  name: keyvalue.key
  parent: appConfiguration
  properties: {
    value: keyvalue.value
  }
}]

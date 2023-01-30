@description('Enables the template to choose different SKU by environment')
param isProd bool

@description('The id for the user-assigned managed identity that runs deploymentScripts')
param devOpsManagedIdentityId string

@secure()
@description('Specifies a password that will be used to secure the Azure SQL Database')
param azureSqlPassword string = ''

param location string

@description('The user running the deployment will be given access to the deployed resources such as Key Vault and App Config svc')
param principalId string = ''

@description('A generated identifier used to create unique resources')
param resourceToken string
param tags object

@description('A user-assigned managed identity that is used by the App Service app')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'web-${resourceToken}-identity'
  location: location
  tags: tags
}

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

@description('Built in \'Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var appConfigurationRoleDefinitionId = '516239f1-63e1-4d78-a4de-a74fb236a071'

// these AADB2C settings are also documented in the create-AADB2C-app-registrations.md.md. Please keep both locations in sync

@minLength(1)
@description('A scope used by the front-end public web app to get authorized access to the public web api. Looks similar to https://myb2ctestorg.onmicrosoft.com/fbb6ce3b-c65f-4708-ae94-5069d1f821b4/Attendee')
param frontEndAzureAdB2CApiScope string

@minLength(1)
@description('A unique identifier of the public facing front-end web app')
param frontEndAzureAdB2cClientId string

@secure()
@minLength(1)
@description('A secret generated by Azure AD B2C so that your web app can establish trust with Azure AD B2C')
param frontEndAzureAdB2cClientSecret string

@minLength(1)
@description('A unique identifier of the public facing API web app')
param apiAzureAdB2cClientId string

@minLength(1)
@description('The domain for the Azure B2C tenant: e.g. myb2ctestorg.onmicrosoft.com')
param azureAdB2cDomain string

@minLength(1)
@description('The url for the Azure B2C tenant: e.g. https://myb2ctestorg.b2clogin.com')
param azureAdB2cInstance string

@minLength(1)
@description('A unique identifier of the Azure AD B2C tenant')
param azureAdB2cTenantId string

@minLength(1)
@description('An Azure AD B2C flow that defines behaviors relating to user sign-up and sign-in. Also known as an Azure AD B2C user flow.')
param azureAdB2cSignupSigninPolicyId string

@minLength(1)
@description('An Azure AD B2C flow that enables users to reset their passwords. Also known as an Azure AD B2C user flow.')
param azureAdB2cResetPolicyId string

@minLength(1)
@description('A URL provided by your web app that will clear session info when a user signs out')
param azureAdB2cSignoutCallback string


@description('Grant the \'Data Reader\' role to the user-assigned managed identity, at the scope of the resource group.')
resource appConfigRoleAssignmentForWebApps 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appConfigurationRoleDefinitionId, appConfigSvc.id, managedIdentity.name, resourceToken)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    description: 'Grant the "Data Reader" role to the user-assigned managed identity so it can access the azure app configuration service.'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'list'
            'get'
            'set'
          ]
        }
      }
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

// use the parameter defined Azure AD B2C settings to save data that the web apps will use to connect to AADB2C
module azureAdSettings 'azureAdSettings.bicep' = {
  name: 'azureAdSettings'
  params: {
    keyVaultName: kv.name
    appConfigurationServiceName: appConfigSvc.name
    apiAzureAdB2cClientId: apiAzureAdB2cClientId
    azureAdB2cDomain: azureAdB2cDomain
    azureAdB2cInstance: azureAdB2cInstance
    azureAdB2cResetPolicyId: azureAdB2cResetPolicyId
    azureAdB2cSignoutCallback: azureAdB2cSignoutCallback
    azureAdB2cSignupSigninPolicyId: azureAdB2cSignupSigninPolicyId
    azureAdB2cTenantId: azureAdB2cTenantId
    frontEndAzureAdB2CApiScope: frontEndAzureAdB2CApiScope
    frontEndAzureAdB2cClientId: frontEndAzureAdB2cClientId
    frontEndAzureAdB2cClientSecret: frontEndAzureAdB2cClientSecret
  }
}

resource baseApiUrlAppConfigSetting 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:RelecloudApi:BaseUri'
  properties: {
    value: 'https://${callcenterApi.properties.defaultHostName}'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource sqlConnStrAppConfigSetting 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:SqlDatabase:ConnectionString'
  properties: {
    value: 'Server=tcp:${sqlSetup.outputs.sqlServerFqdn},1433;Initial Catalog=${sqlSetup.outputs.sqlCatalogName};Authentication=Active Directory Default'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource redisConnAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:RedisCache:ConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${redisSetup.outputs.keyVaultRedisConnStrName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource frontEndClientSecretAppCfg 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'AzureAd:ClientSecret'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${frontEndClientSecretName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    checkIfClientSecretExists
  ]
}

var frontEndClientSecretName = 'AzureAd--ClientSecret'

resource checkIfClientSecretExists 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'checkIfClientSecretExists'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    scriptContent: 'result=$(az keyvault secret list --vault-name ${kv.name} --query "[?name==\'${frontEndClientSecretName}\'].name" -o tsv); if [[ \${#result} -eq 0 ]]; then az keyvault secret set --name \'AzureAd--ClientSecret\' --vault-name ${kv.name} --value 1 --only-show-errors > /dev/null; fi'
    arguments: '--resourceToken \'${resourceToken}\''
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource storageAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:StorageAccount:ConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${storageSetup.outputs.keyVaultStorageConnStrName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

var aspNetCoreEnvironment = isProd ? 'Production' : 'Development'

resource callcenterWeb 'Microsoft.Web/sites@2021-03-01' = {
  name: 'callcenter-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'web-call-center'
    })
  properties: {
    serverFarmId: callCenterAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::callcenterSubnet.id
  }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'App:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    dependsOn: [
      appSettings
    ]
  }
}

resource publicWeb 'Microsoft.Web/sites@2021-03-01' = {
  name: 'publicweb-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'web-public'
    })
  properties: {
    serverFarmId: publicWebAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::publicwebSubnet.id
  }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'App:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    dependsOn: [
      appSettings
    ]
  }
}

resource callcenterApi 'Microsoft.Web/sites@2021-01-15' = {
  name: 'callcenterapi-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'call-center-api'
    })
  properties: {
    serverFarmId: callCenterApiAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::callcenterapiSubnet.id
  }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'Api:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    dependsOn: [
      appSettings
    ]
  }
}


resource publicApi 'Microsoft.Web/sites@2021-01-15' = {
  name: 'publicapi-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'public-api'
    })
  properties: {
    serverFarmId: publicApiAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::publicapiSubnet.id
  }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'Api:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    dependsOn: [
      appSettings
    ]
  }
}

resource appConfigSvc 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: '${resourceToken}-appconfig'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
}

var appServicePlanSku = (isProd) ? 'P1v2' : 'B1'

resource callCenterAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-callcenter-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

resource publicWebAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-publicweb-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

resource publicApiAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-publicapi-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

resource callCenterApiAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-callcenterapi-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

module publicWebServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${publicWebAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: publicWebAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
}

module callCenterServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${callCenterAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: callCenterAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
}

module publicApiServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${publicApiAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: publicApiAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
}

module callCenterApiServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${callCenterApiAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: callCenterApiAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
}

resource webLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'web-${resourceToken}-log'
  location: location
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

module webApplicationInsightsResources './applicationinsights.bicep' = {
  name: 'web-${resourceToken}-app-insights'
  params: {
    resourceToken: resourceToken
    location: location
    tags: tags
    workspaceId: webLogAnalyticsWorkspace.id
  }
}


resource adminVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'admin-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForTemplateDeployment: true
    accessPolicies: [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

var defaultSqlPassword = 'a${toUpper(uniqueString(subscription().id, resourceToken))}32${toUpper(uniqueString(managedIdentity.properties.principalId, resourceToken))}Q'

resource kvSqlAdministratorPassword 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: adminVault
  name: 'sqlAdministratorPassword'
  properties: {
    // uniqueString produces a 13 character result
    // concatenation of 2 unique strings produces a 26 character password unique to your subscription per environment
    value: (length(azureSqlPassword) == 0 ) ? defaultSqlPassword : azureSqlPassword
  }
}

var sqlAdministratorLogin = 'sqladmin${resourceToken}'
resource kvSqlAdministratorLogin 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: adminVault
  name: 'sqlAdministratorLogin'
  properties: {
    value: sqlAdministratorLogin
  }
}

module sqlSetup 'azureSqlDatabase.bicep' = {
  name: 'sqlSetup'
  scope: resourceGroup()
  params: {
    devOpsManagedIdentityId: devOpsManagedIdentityId
    isProd: isProd
    location: location
    managedIdentity: {
      name: managedIdentity.name
      id: managedIdentity.id
      properties: {
        clientId: managedIdentity.properties.clientId
        principalId: managedIdentity.properties.principalId
        tenantId: managedIdentity.properties.tenantId
      }
    }
    resourceToken: resourceToken
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: adminVault.getSecret(kvSqlAdministratorPassword.name)
    tags: tags
  }
  dependsOn: [
    vnet
  ]
}

var privateEndpointNameForRedis = 'privateEndpointForRedis'
module redisSetup 'azureRedisCache.bicep' = {
  name: 'redisSetup'
  scope: resourceGroup()
  params: {
    devOpsManagedIdentityId: devOpsManagedIdentityId
    isProd: isProd
    location: location
    resourceToken: resourceToken
    tags: tags
    privateEndpointNameForRedis: privateEndpointNameForRedis
    privateEndpointVnetName: vnet.name
    privateEndpointSubnetName: privateEndpointSubnetName
  }
}

module storageSetup 'azureStorage.bicep' = {
  name: 'storageSetup'
  scope: resourceGroup()
  params: {
    isProd: isProd
    location: location
    resourceToken: resourceToken
    tags: tags
  }
  dependsOn: [
    vnet
  ]
}

var privateEndpointSubnetName = 'subnetPrivateEndpoints'
var subnetPublicApiAppService = 'subnetPublicApiAppService'
var subnetCallcenterApiAppService = 'subnetCallcenterApiAppService'
var subnetPublicwebAppService = 'subnetPublicwebAppService'
var subnetCallcenterAppService = 'subnetCallcenterAppService'

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: 'rc-${resourceToken}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetPublicwebAppService
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: subnetCallcenterAppService
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: subnetPublicApiAppService
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: subnetCallcenterApiAppService
        properties: {
          addressPrefix: '10.0.4.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
    ]
  }

  resource callcenterapiSubnet 'subnets' existing = {
    name: subnetCallcenterApiAppService
  }

  resource publicapiSubnet 'subnets' existing = {
    name: subnetPublicApiAppService
  }

  resource callcenterSubnet 'subnets' existing = {
    name: subnetCallcenterAppService
  }
  resource publicwebSubnet 'subnets' existing = {
    name: subnetPublicwebAppService
  }
}

resource privateEndpointForSql 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForSql'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlSetup.outputs.sqlServerName}/${sqlSetup.outputs.sqlDatabaseName}'
        properties: {
          privateLinkServiceId: sqlSetup.outputs.sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneNameForSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForSql_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForSql
  name: '${privateDnsZoneNameForSql.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource sqlPvtEndpointDnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForSql.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForSql.id
        }
      }
    ]
  }
}

resource redisPvtEndpointDnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointNameForRedis}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: redisSetup.outputs.privateDnsZoneId
        }
      }
    ]
  }
}

// private link for Key vault

resource privateDnsZoneNameForKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForKv_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForKv
  name: '${privateDnsZoneNameForKv.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource pvtEndpointDnsGroupNameForKv 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForKv.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForKv.id
        }
      }
    ]
  }
}

resource privateEndpointForKv 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForKv'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: kv.name
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// private link for App Config Svc

resource privateDnsZoneNameForAppConfig 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azconfig.io'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForAppConfig_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForAppConfig
  name: '${privateDnsZoneNameForAppConfig.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource pvtEndpointDnsGroupNameForAppConfig 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForAppConfig.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForAppConfig.id
        }
      }
    ]
  }
}

resource privateEndpointForAppConfig 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForAppConfig'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: appConfigSvc.name
        properties: {
          privateLinkServiceId: appConfigSvc.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}

// app config vars cannot be set without public network access
// the above config settings must depend on this block to ensure
// access is allowed before we try saving the setting
resource openConfigSvcsForEdits 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'openConfigSvcsForEdits'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'APP_CONFIG_SVC_NAME'
        value: appConfigSvc.name
      }
      {
        name: 'KEY_VAULT_NAME'
        value: kv.name
      }
      {
        name: 'RESOURCE_GROUP'
        secureValue: resourceGroup().name
      }
    ]
    scriptContent: '''
      az appconfig update --name $APP_CONFIG_SVC_NAME --resource-group $RESOURCE_GROUP --enable-public-network true
      az keyvault update --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP  --public-network-access Enabled
      '''
  }
}

resource closeConfigSvcsForEdits 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (isProd) {
  name: 'closeConfigSvcsForEdits'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'APP_CONFIG_SVC_NAME'
        value: appConfigSvc.name
      }
      {
        name: 'KEY_VAULT_NAME'
        value: kv.name
      }
      {
        name: 'RESOURCE_GROUP'
        secureValue: resourceGroup().name
      }
    ]
    scriptContent: '''
      az appconfig update --name $APP_CONFIG_SVC_NAME --resource-group $RESOURCE_GROUP --enable-public-network false
      az keyvault update --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP  --public-network-access Disabled
      '''
  }
  // app config vars cannot be set without public network access
  // now that they are set - we block public access for prod
  // and leave public access enabled to support local dev scenarios
  dependsOn:[
    baseApiUrlAppConfigSetting
    sqlConnStrAppConfigSetting
    redisConnAppConfigKvRef
    frontEndClientSecretAppCfg
    storageAppConfigKvRef
  ]
}

output WEB_PUBLIC_URI string = publicWeb.properties.defaultHostName
output WEB_CALLCENTER_URI string = callcenterWeb.properties.defaultHostName
output PUBLIC_API_URI string = publicApi.properties.defaultHostName
output CALLCENTER_API_URI string = callcenterApi.properties.defaultHostName

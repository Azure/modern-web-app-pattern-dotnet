// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The Azure region used to host the deployment script')
param location string

@description('The owner managed identity used to auto-approve the private endpoint')
param managedIdentityName string

@description('Force the deployment script to run')
param utcValue string = utcNow()

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

@description('Built in \'Contributor\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var contributerRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource grantContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(contributerRoleId, managedIdentityName, resourceGroup().name)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', contributerRoleId)
    principalId: managedIdentity.properties.principalId
  }
}

resource approval 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'auto-approve-private-endpoint'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.47.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
    ]
    scriptContent: 'rg_name="$ResourceGroupName"; webapp_ids=$(az webapp list -g $rg_name --query "[].id" -o tsv); for webapp_id in $webapp_ids; do fd_conn_ids=$(az network private-endpoint-connection list --id $webapp_id --query "[?properties.provisioningState == \'Pending\'].id" -o tsv); for fd_conn_id in $fd_conn_ids; do az network private-endpoint-connection approve --id "$fd_conn_id" --description "ApprovedByCli"; done; done'         
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    grantContributorRole
  ]
}

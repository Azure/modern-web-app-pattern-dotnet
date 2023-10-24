# Steps to deploy the Network Isolated implementation
This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. These steps guide you through using the jump host that is deployed when performing a network isolated deployment because access to resources will be restricted from public network access and must be performed from a machine connected to the vnet.

## Prerequisites

We recommend that you use a Dev Container to deploy this application.  The requirements are as follows:

- [Azure Subscription](https://azure.microsoft.com/pricing/member-offers/msdn-benefits-details/).
- [Visual Studio Code](https://code.visualstudio.com/).
- [Docker Desktop](https://www.docker.com/get-started/).
- [Permissions to register an application in Azure AD](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app).
- Visual Studio Code [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

If you do not wish to use a Dev Container, please refer to the [prerequisites](prerequisites.md) for detailed information on how to set up your development system to build, run, and deploy the application.

> ⚠️ We are using version 1.3.0 for AZD while awaiting feedback on a known bicep issue.

## Steps to deploy the reference implementation

For users familiar with the deployment process, you can use the following list of the deployments commands as a quick reference. The commands assume you have logged into Azure through the Azure CLI and Azure Developer CLI and have selected a suitable subscription:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
azd env new eapdotnetmwa
azd env set NETWORK_ISOLATION true
azd env set DEPLOY_HUB_NETWORK true
azd env set COMMON_APP_SERVICE_PLAN false
azd env set OWNER_NAME <a name listed as resource owner in Azure tags>
azd env set OWNER_EMAIL <an email address alerted by Azure budget>
azd env set AZURE_LOCATION westus3
```

Set a password for the Azure jumphost VM where code will be deployed from:
> ⚠️ Password must be longer than 12 (no more than 123) and have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character.
```
azd env set ADMIN_PASSWORD "AV@lidPa33word"
```

Set a password for the Azure SQL Database.
> ⚠️ Password must be longer than 8 (no more than 128) and have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character.
```
azd env set DATABASE_PASSWORD "AV@lidPa33word"
```

Provision the Azure resources (about 55-minutes to provision):
```
azd provision
```

**Login**
1. Use Bastion to log into Windows VM JumpHost
   1. Find admin user name in Key Vault deployed to the hub
   1. Find admin password in Key Vault deployed to the hub
   1. Use Bastion to log in for first time access

**First time setup**
1. Launch Windows Terminal to setup tools
    1. Install AZD Tool
        
        `powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"`

    1. Download Dotnet SDK
        
        `powershell -ex AllSigned -c "Invoke-RestMethod 'https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1' -OutFile dotnet-install.ps1"`

    1. Install Dotnet SDK

        `.\dotnet-install.ps1 -Channel 6.0`

    1. Add dotnet to the path environment variable

        ![#Add dotnet to the path variable](./docs/images/jumphost-path-setup.png)

    1. close and restart terminal
1. Use the new Terminal to get the code
    1. `mkdir \dev`
    1. `cd \dev`
    1. `git clone https://github.com/Azure/modern-web-app-pattern-dotnet`
    1. `cd .\modern-web-app-pattern-dotnet`
1. Authenticate
    1. Sign into Edge (if required by your AD tenant) and choose "Allow my organization to manage my device"
    1. `az login --scope https://graph.microsoft.com//.default`
    1. `az account set --subscription <azure subscription for Relecloud deployment>`
    1. `azd auth login`
1. Switch branch <!-- todo remove this -->
    1. `git checkout -b infra-refactor origin/kschlobohm/infra-refactor`
1. Set required AZD variables
    1. `azd env new <name from devcontainer terminal>`
    1. `azd env set AZURE_LOCATION <location from devcontainer terminal>`
    1. `azd env set AZURE_SUBSCRIPTION_ID <subscription id from devcontainer terminal>`
    1. `azd env set AZURE_RESOURCE_GROUP <name of workload resource group from Azure portal>`
1. Create the Azure AD app registration from the new terminal (about 3-minutes to register)
    1. `.\infra\scripts\create-app-registrations.ps1 -g '<name from Azure portal for workload resource group>'`
1. Deploy the code from the jump host (about 4-minutes to deploy)
    1. `azd deploy`

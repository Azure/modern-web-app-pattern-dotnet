# Steps to deploy the reference implementation

This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. These steps guide you through using the jump host that is deployed when performing a network isolated deployment because access to resources will be restricted from public network access and must be performed from a machine connected to the vnet.

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
azd env set DATABASE_PASSWORD "AV@lidPa33word"
azd env set AZURE_LOCATION westus3
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

    1. close and restart terminal
1. Use the new Terminal to get the code
    1. `mkdir \dev`
    1. `cd \dev`
    1. `git clone https://github.com/Azure/modern-web-app-pattern-dotnet`
1. Authenticate
    1. Sign into Edge (if required by your AD tenant) and choose "Allow my organization to manage my device"
    1. `az login --scope https://graph.microsoft.com//.default`
    1. `az account set --subscription <azure subscription for Relecloud deployment>`
    1. `azd auth login`
1. Create the Azure AD app registration from the new terminal
    1. `.\infra\scripts\createAppRegistrations.ps1 -g '<name from Azure portal for workload resource group>'`
1. Set required AZD variables
    1. `azd env new <name from devcontainer terminal>`
    1. `azd env set AZURE_ENV_NAME <name from devcontainer terminal>`
    1. `azd env set AZURE_LOCATION <location from devcontainer terminal>`
    1. `azd env set AZURE_SUBSCRIPTION_ID <subscription id from devcontainer terminal>`
1. Deploy the code from the jump host
    1. `azd deploy`

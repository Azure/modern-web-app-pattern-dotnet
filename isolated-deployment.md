# isolated-deployment.md



## Steps to deploy the reference implementation

This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. There are nine steps, including teardown.

For users familiar with the deployment process, you can use the following list of the deployments commands as a quick reference. The commands assume you have logged into Azure through the Azure CLI and Azure Developer CLI and have selected a suitable subscription:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
azd env new eapdotnetmwa
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
1. Launch Windows Terminal
    1. `git clone https://github.com/Azure/modern-web-app-pattern-dotnet`
    1. `winget install Microsoft.Azd`
    1. `winget install Microsoft.DotNet.SDK.6`
    1. close and restart terminal
1. Settings from local environment
    1. 
1. Deploy
    1. `azd deploy`

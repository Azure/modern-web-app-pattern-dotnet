# isolated-deployment.md

**Login**
1. Use Bastion to log into Windows VM JumpHost
   1. Find admin user name in Key Vault
   1. Find admin password in Key Vault
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

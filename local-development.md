# Local Development

Relecloud developers use Visual Studio to develop locally and they use
dev containers with docker-compose to run local SQL instances that
allow developers to make schema changes without impacting others.

To connect to the shared database the dev team uses connection strings
from Key Vault and App Configuration Service. Devs use the following
script to retrieve data and store it as
[User Secrets](https://docs.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-6.0&tabs=windows)
on their workstation.

Using the `secrets.json` file helps the team keep their credentials
secure. The file is stored outside of the source control directory so
the data is never accidentally checked-in. And the devs don't share
credentials over email or other ways that could compromise their
security.

Managing secrets from Key Vault and App Configuration ensures that only
authorized team members can access the data and also centralizes the
administration of these secrets so they can be easily changed.

New team members should setup their environment by following these steps.

1. Open a PowerShell prompt at the root of the project where the `azure.yaml` is located.
1. Set variables
    1. The email address for the current user
        ```pwsh
        $emailAddr = (Get-AzContext).Account.Id
        ```
    1. The objectId of the current user
        ```pwsh
        $objectId = (Get-AzAdUser -UserPrincipalName $emailAddr).Id
        ```
    1. A display name for the current user
        ```pwsh
        $displayName = (Get-AzAdUser -UserPrincipalName $emailAddr).DisplayName 
        ```
    1. The name of the Azure SQL Database (from portal or Azure Dev CLI environment)
        ```pwsh
        $sqlDatabaseName = (azd env get-values --output json | ConvertFrom-Json).SQL_DATABASE_NAME
        ```
    1. The name of the Azure SQL Server (from portal or Azure Dev CLI environment)
        ```pwsh
        $sqlServerName = (azd env get-values --output json | ConvertFrom-Json).SQL_SERVER_NAME
        ```
    1. The uri for Azure App Configuration Service (from portal or Azure Dev CLI environment)
        ```pwsh
        $appConfigServiceUri = (azd env get-values --output json | ConvertFrom-Json).APP_CONFIG_SERVICE_URI
        ```
1. Setup the **Relecloud.Web.CallCenter** project User Secrets
    1. Change to the **Relecloud.Web.CallCenter** directory
        ```pwsh
        cd ./src/Relecloud.Web.CallCenter
        ```
    1. Set the user secret to identify where App Configuration Service is located
        ```pwsh
        dotnet user-secrets set App:AppConfig:Uri $appConfigServiceUri
        ```
    1. Override the BaseUri so that web api calls are handled locally
        ```pwsh
        dotnet user-secrets set App:RelecloudApi:BaseUri http://localhost:7242
        ```
        > This URI can be found in the `launchsettings.json` file for the project

1. Setup the **Relecloud.Web.CallCenter.Api** project User Secrets
    1. Change out of the front-end web app to the root directory
        ```pwsh
        cd ../..
        ```
    1. Change to the **Relecloud.Web.CallCenter.Api** directory
        ```pwsh
        cd ./src/Relecloud.Web.CallCenter.Api
        ```
    1. Set the user secret to identify where App Configuration Service is located
        ```pwsh
        dotnet user-secrets set App:AppConfig:Uri $appConfigServiceUri
        ```
1. When connecting to Azure SQL database you'll connect with your Microsoft Entra ID account.
    1. Change out of the front-end web app to the root directory
        ```pwsh
        cd ../..
        ```
    1. Run the following script to add yourself as a user in the SQL users table
        ```pwsh
        ./infra/core/database/create-sql-user-and-role.ps1 -SqlServerName $sqlServerName -SqlDatabaseName $sqlDatabaseName -ObjectId $objectId -DisplayName $displayName -DatabaseRoles @('db_owner')
        ```
1. Open the Visual Studio solution `./src/Relecloud.sln`
1. Right-click the **Relecloud** solution and pick **Set Startup Projects...**
1. Choose **Multiple startup projects**
1. Change the dropdowns for *Relecloud.Web.CallCenter* and *Relecloud.Web.CallCenter.Api* to the action of **Start**.
1. Click **Ok** to close the popup
1. Press **F5** to start debugging the web app in Visual Studio

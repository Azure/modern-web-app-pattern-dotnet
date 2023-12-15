# Modern web app pattern for .NET
This reference implementation provides a production-grade web application that uses best practices from our guidance and gives developers concrete examples to build their own modern web application in Azure.

The modern web app pattern shows you how business goals influence incremental changes for web apps deployed to the cloud. It defines the implementation guidance you need to modernize web apps the right way. The modern web app pattern demonstrates how existing functionality changes, and is refactored, using the Strangler Fig pattern as business scenarios ask web apps to add new features and update non-functional requirements. It shows you how to use cloud design patterns in your code and choose managed services so that you can rapidly iterate in the cloud. Here's an outline of the contents in this readme:

<!-- content lives in GH until published-->
- Guidance
    - [Plan the implementation](./guide/plan-the-implementation.md)
    - [Apply the pattern](./guide/apply-the-pattern.md)
- [Azure Architecture Center guidance](#azure-architecture-center-guidance)
- [Architecture](#architecture)
- [Workflow](#workflow)
- [Steps to deploy the reference implementation](#steps-to-deploy-the-reference-implementation)
- [Additional links](#additional-links)
- [Data Collection](#data-collection)

## Azure Architecture Center guidance

This project has a [companion article in the Azure Architecture Center](https://aka.ms/eap/rwa/dotnet/doc) that describes design patterns and best practices for migrating to the cloud. We suggest you read it as it will give important context to the considerations applied in this implementation.

## Architecture

![Diagram showing the architecture of the reference implementation.](./assets/images/relecloud-solution-diagram.png)

## Workflow
> ⚠️ Pending documentation of workflow - (Business reporting experience) covered by #1871276

## Prerequisites

We recommend that you use a Dev Container to deploy this application.  The requirements are as follows:

- [Azure Subscription](https://azure.microsoft.com/pricing/member-offers/msdn-benefits-details/).
- [Visual Studio Code](https://code.visualstudio.com/).
- [Docker Desktop](https://www.docker.com/get-started/).
- [Permissions to register an application in Microsoft Entra ID](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app).
- Visual Studio Code [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

If you do not wish to use a Dev Container, please refer to the [prerequisites](prerequisites.md) for detailed information on how to set up your development system to build, run, and deploy the application.

> ⚠️ We are using version 1.3.0 for AZD while awaiting feedback on a known bicep issue.

## Steps to deploy the reference implementation

This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. There are nine steps, including teardown.

For users familiar with the deployment process, you can use the following list of the deployments commands as a quick reference. The commands assume you have logged into Azure through the Azure CLI and Azure Developer CLI and have selected a suitable subscription:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
azd env new dotnetwebapp
azd env set AZURE_LOCATION westus3
azd up
```

The following detailed deployment steps assume you are using a Dev Container inside Visual Studio Code.

### 1. Clone the repo

Clone the repository from GitHub:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
```

### 2. Open Dev Container in Visual Studio Code (optional)

If required, ensure Docker Desktop is started and enabled for your WSL terminal [more details](https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers#install-docker-desktop). Open the repository folder in Visual Studio Code. You can do this from the command prompt:

```shell
code .
```

Once Visual Studio Code is launched, you should see a popup allowing you to click on the button **Reopen in Container**.

![Reopen in Container](assets/images/vscode-reopen-in-container.png)

If you don't see the popup, open the Visual Studio Code Command Palette to execute the command. There are three ways to open the command palette:

- For Mac users, use the keyboard shortcut ⇧⌘P
- For Windows and Linux users, use Ctrl+Shift+P
- From the Visual Studio Code top menu, navigate to View -> Command Palette.

Once the command palette is open, search for `Dev Containers: Rebuild and Reopen in Container`.

![WSL Ubuntu](assets/images/vscode-reopen-in-container-command.png)

### 3. Create a new environment

Use the VS Code terminal to run the following commands to create a new environment.

The environment name should be less than 18 characters and must be comprised of lower-case, numeric, and dash characters (for example, `dotnetwebapp`).  The environment name is used for resource group naming and specific resource naming. Also, select a password for the admin user of the database.

If not using PowerShell 7+, run the following command:

```shell
pwsh
```

Run the following commands to set these values and create a new environment:

```pwsh
azd env new dotnetwebapp
```

You can substitute the environment name with your own value.

By default, Azure resources are sized for a "development" mode. If doing a Production deployment, set the `AZURE_ENV_TYPE` to `prod` using the following command:

```pwsh
azd env set AZURE_ENV_TYPE prod
```

### 4. Log in to Azure

Before deploying, you must be authenticated to Azure and have the appropriate subscription selected. Run the following command to authenticate:

```pwsh
azd auth login
```

```pwsh
Import-Module Az.Resources
```

```pwsh
Connect-AzAccount
```

Each command will open a browser allowing you to authenticate.  To list the subscriptions you have access to:

```pwsh
Get-AzSubscription
```

To set the active subscription:

```pwsh
$AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
azd env set AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID
Set-AzContext -SubscriptionId $AZURE_SUBSCRIPTION_ID
```

### 5. Select a region for deployment

The application can be deployed in either a single region or multi-region manner. You can find a list of available Azure regions by running the following Azure CLI command.

> ```pwsh
> (Get-AzLocation).Location
> ```

Set the `AZURE_LOCATION` to the primary region:

```pwsh
azd env set AZURE_LOCATION westus3
```

### 6. Provision the application

Run the following command to create the infrastructure (about 15-minutes to provision):

```pwsh
azd provision --no-prompt
```

**Create App Registrations**

Relecloud devs have automated the process of creating Azure
AD resources that support the authentication features of the
web app. They use the following command to create two new
App Registrations within Microsoft Entra ID. The command is also
responsible for saving configuration data to Key Vault and
App Configuration so that the web app can read this data
(about 3-minutes to register).

```pwsh
./infra/scripts/postprovision/call-create-app-registrations.ps1
```

**Set Configuration**

Relecloud devs have automated the process of configuring the environment.

```pwsh
./infra/scripts/predeploy/call-set-app-configuration.ps1
```

### 7. Deploy the application

Run the following command to deploy the code to the created infrastructure (about 4-minutes to deploy):

```pwsh
azd deploy
```

The provisioning and deployment process can take anywhere from 20 minutes to over an hour, depending on system load and your bandwidth.

### 8. Open and use the application

Use the following to find the URL for the Relecloud application that you have deployed:

```pwsh
(azd env get-values --output json | ConvertFrom-Json).WEB_URI
```

![screenshot of Relecloud app home page](assets/images/WebAppHomePage.png)

### 9. Teardown

To tear down the deployment, run the following command:

```pwsh
azd down
```

## Additional links

- [Plan the implementation](plan-the-implementation.md)
- [Apply the pattern](apply-the-pattern.md)
- [Known issues](known-issues.md)
- [Developer patterns](simulate-patterns.md)
- [Find additional resources](additional-resources.md)
- [Report security concerns](SECURITY.md)
- [Find Support](SUPPORT.md)
- [Contributing](CONTRIBUTING.md)

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkId=521839. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

### Telemetry Configuration

Telemetry collection is on by default.

To opt out, run the following command `azd env set ENABLE_TELEMETRY` to `false` in your environment.
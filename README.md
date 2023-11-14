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

![Diagram showing the architecture of the reference implementation.](./docs/images/relecloud-solution-diagram.png)

## Workflow
> ⚠️ Pending documentation of workflow - (Business reporting experience) covered by #1871276

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

This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. There are nine steps, including teardown.

For users familiar with the deployment process, you can use the following list of the deployments commands as a quick reference. The commands assume you have logged into Azure through the Azure CLI and Azure Developer CLI and have selected a suitable subscription:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
azd env new eapdotnetmwa
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

![Reopen in Container](docs/images/vscode-reopen-in-container.png)

If you don't see the popup, open the Visual Studio Code Command Palette to execute the command. There are three ways to open the command palette:

- For Mac users, use the keyboard shortcut ⇧⌘P
- For Windows and Linux users, use Ctrl+Shift+P
- From the Visual Studio Code top menu, navigate to View -> Command Palette.

Once the command palette is open, search for `Dev Containers: Rebuild and Reopen in Container`.

![WSL Ubuntu](docs/images/vscode-reopen-in-container-command.png)

### 3. Create a new environment

The environment name should be less than 18 characters and must be comprised of lower-case, numeric, and dash characters (for example, `eapdotnetmwa`).  The environment name is used for resource group naming and specific resource naming. Also, select a password for the admin user of the database.

Run the following commands to set these values and create a new environment:

```shell
azd env new eapdotnetmwa
```

Substitute the environment name and database password for your own values.

By default, Azure resources are sized for a "development" mode. If doing a Production deployment, set the `AZURE_ENV_TYPE` to `prod` using the following code:

```shell
azd env set AZURE_ENV_TYPE prod
```

### 4. Log in to Azure

Before deploying, you must be authenticated to Azure and have the appropriate subscription selected.  To authenticate:

```shell
az login --scope https://graph.microsoft.com//.default
azd auth login
```

Each command will open a browser allowing you to authenticate.  To list the subscriptions you have access to:

```shell
az account list
```

To set the active subscription:

```shell
export AZURE_SUBSCRIPTION="<your-subscription-id>"
az account set --subscription $AZURE_SUBSCRIPTION
azd env set AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION
```

### 5. Select a region for deployment

The application can be deployed in either a single region or multi-region manner. You can find a list of available Azure regions by running the following Azure CLI command.

> ```shell
> az account list-locations --query "[].name" -o tsv
> ```

Set the `AZURE_LOCATION` to the primary region:

```shell
azd env set AZURE_LOCATION westus3
```

If doing a multi-region deployment, set the `AZURE_LOCATION2` to the secondary region:

```shell
azd env set AZURE_LOCATION2 eastus
```

Make sure the secondary region is a paired region with the primary region (`AZURE_LOCATION`). Paired regions are required to support [geo-zone-redundant storage (GZRS) failover](https://learn.microsoft.com/azure/storage/common/storage-disaster-recovery-guidance). For a full list of region pairs, see [Azure region pairs](https://learn.microsoft.com/azure/reliability/cross-region-replication-azure#azure-cross-region-replication-pairings-for-all-geographies). We have validated the following paired regions.

| AZURE_LOCATION | AZURE_LOCATION2 |
| ----- | ----- |
| westus3 | eastus |
| westeurope | northeurope |
| australiaeast | australiasoutheast |

### 6. Provision the application

Run the following command to create the infrastructure (about 15-minutes to provision):

```shell
azd provision --no-prompt
```

**Create App Registrations**

Relecloud devs have automated the process of creating Azure
AD resources that support the authentication features of the
web app. They use the following command to create two new
App Registrations within Azure AD. The command is also
responsible for saving configuration data to Key Vault and
App Configuration so that the web app can read this data
(about 3-minutes to register).

```sh
./infra/scripts/create-app-registrations.sh -g '<name from Azure portal for workload resource group>'
```

### 7. Deploy the application

Run the following command to deploy the code to the created infrastructure (about 4-minutes to deploy):

```shell
azd deploy
```

If you are doing a multi-region deployment, you must also deploy the code to the secondary region (about 4-minutes to deploy):

```shell
SECONDARY_RESOURCE_GROUP=$(azd env get-values --output json | jq -r .secondary_resource_group)
azd env set AZURE_RESOURCE_GROUP $SECONDARY_RESOURCE_GROUP
azd deploy
```

The provisioning and deployment process can take anywhere from 20 minutes to over an hour, depending on system load and your bandwidth.


### 8. Open and use the application

Use the following to find the URL for the Proseware application that you have deployed:

```shell
azd env get-values --output json | jq -r .WEB_URI
```

![screenshot of Relecloud app home page](docs/images/WebAppHomePage.png)

It takes approximately 5 minutes for the Azure App Service to respond to requests using the code deployed during step 6.

### 9. Teardown

To tear down the deployment, run the following command:

```shell
azd down
```

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkId=521839. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

Telemetry collection is on by default.

To opt out, set the environment variable `ENABLE_TELEMETRY` to `false`.

```shell
azd env set ENABLE_TELEMETRY false
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
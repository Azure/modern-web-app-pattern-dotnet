# Steps to deploy the Network Isolated implementation
This section describes the deployment steps for the reference implementation of a modern web application pattern with .NET on Microsoft Azure. These steps guide you through using the jump host that is deployed when performing a network isolated deployment because access to resources will be restricted from public network access and must be performed from a machine connected to the vnet.

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

Provision the Azure resources (about 55-minutes to provision):

```shell
azd provision
```

### Login

The default username for the jump host is `azureadmin` and the password was set earlier. If you did not set an ADMIN_PASSWORD, then one is generated for you.  To retrieve the generated password:

1. Turn off the firewall for the Azure Key Vault:

    - Open the [Azure Portal](https://portal.azure.com)
    - Select the HUB resource group, then select the Azure Key Vault resource
    - In the menu sidebar, select **Networking**.
    - In the **Firewalls and virtual networks** tab, select **Allow public access from all networks**.
    - Select **Apply** at the bottom of the screen.

1. Retrieve the username and password for your jump host:

    - Select **Secrets** from the menu sidebar.
    - Select **Jumphost--AdministratorPassword**.
    - Select the currently enabled version.
    - Press **Show Secret Value**.
    - Note the secret value for later use.
    - Repeat the proecess for the **Jumphost--AdministratorUsername** secret.

Now that you have the username and password:

- Open the [Azure Portal](https://portal.azure.com)
- Select the SPOKE resource group, then select the jump host virtual machine resource.  The resource name starts with `vm-jump`.
- In the menu sidebar, select **Bastion**.
- Enter the username and password in the fields provided.
- Press **Connect** to connect to the jump host.

> **WARNING**
>
> Your organization may not allow the creation of Entra ID application registrations unless the host is joined
> to a domain, InTune managed, or meets other security requirements.  If your organization has such security
> requirements, set those up before continuing.
>
> Microsoft employees:
>
> - The jump host must be InTune managed.
> - Turn off the firewall on the WORKLOAD Key Vault.
> - Create the Entra application registrations from the same system that you used to initially provision resources.
> - Once the application registrations have been created, you can optionally turn on the firewall again.
>
> The other actions (such as azd deploy) should still be run from the jump host.

### First time setup

From the jump host, launch Windows Terminal to setup required tools:

1. Install the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd):

    ```shell
    powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
    ```

1. Install the [dotnet SDK](https://learn.microsoft.com/dotnet/core/tools/dotnet-install-script):

    ```shell
    powershell -ex AllSigned -c "Invoke-RestMethod 'https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1' -OutFile dotnet-install.ps1"
    .\dotnet-install.ps1 -Channel 6.0
    ```

1. Add dotnet to the path environment variable

    ![#Add dotnet to the path variable](./docs/images/jumphost-path-setup.png)

    Add the path: `C:\Users\{username}\AppData\Local\Microsoft\dotnet`.

### Download the code

Use the Windows Terminal to get the code:

```shell
mkdir \dev
cd \dev
git clone https://github.com/Azure/modern-web-app-pattern-dotnet
cd .\modern-web-app-pattern-dotnet
```

### Authenticate to Azure

1. [Sign in to the Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli):

    ```shell
    az login
    ```

    This will open a browser to complete the authentication process.  See [the documentation](https://learn.microsoft.com/cli/azure/authenticate-azure-cli) for instructions on other mechanisms to sign in to the Azure CLI.

1. [Sign in to azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/reference#azd-auth-login):

    ```shell
    azd auth login
    ```

    This will also open a browser to complete the authentication process.

### Recreate the Azure Developer CLI environment on the jump host

Set up the required Azure Developer CLI environment:

```shell
azd env new <Name of created environment>
azd env set AZURE_LOCATION <Location>
azd env set AZURE_RESOURCE_GROUP <name of workload resource group from Azure Portal>
azd env set AZURE_SUBSCRIPTION_ID "<Azure subscription ID>"
az account set --subscription "<Azure Subscription ID>"
```

Ensure you use the same configuration you used when provisioning the services.

### Register the application in Microsoft Entra

Give yourself permission to access the WORKLOAD key vault and app config resources.

- If running from your local system instead of the jump host, turn off the firewall in the key vault and app config resources.
- In the WORKLOAD key vault, add yourself to the _Key Vault Secrets Officer_ role in **Access Control (IAM)**.
- In the WORKLOAD app config, add yourself to the _App Configuration Data Owner_ role in **Access Control (IAM)**.

> **WARNING**
>
> It takes approximately 5 minutes to propagate RBAC and firewall changes.

Create the Entra application registrations:

- Open a new PowerShell terminal.
- Change directory to the `modern-web-app-pattern-dotnet` directory.
- Run `.\infra\scripts\create-app-registrations.ps1` -g `<name of your workload resource group>`
- Wait approximately 5 minutes for the registration to propagate.

### Deploy the code from the jump host

Deploy the code from the jump host:

```shell
azd deploy
```

It takes approximately 5 minutes to deploy the code.

> **WARNING**
> In some scenarios, the DNS entries for resources secured with Private Endpoint may have been cached incorrectly. It can take up to 10-minutes for the DNS cache to expire.
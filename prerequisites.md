# Prerequisites

```
 If you want to use a VSCode DevContainer see the `VSCode DevContainer prerequisites` section below
```

## Pre-requisites

The following tools are pre-requisites to running the associated deployment steps on Windows without using the Dev Container.

1. To run the scripts, Windows users require Powershell 7.2 (LTS) or above. Alternatively, you can use a bash terminal using [Windows Subsystem for Linux](https://learn.microsoft.com/windows/wsl/install). macOS users can use a bash terminal.

   1. PowerShell users - [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
       Run the following to verify that you're running the latest PowerShell
   
       ```ps1
       $PsVersionTable
       ```

1. [Install Git](https://github.com/git-guides/install-git)
    Run the following to verify that git is available
    ```ps1
    git version
    ```

1. [Install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli).
    Run the following command to verify that you're running version
    2.38.0 or higher.

    ```ps1
    az version
    ```
    
    After the installation, run the following command to [sign in to Azure interactively](https://learn.microsoft.com/cli/azure/authenticate-azure-cli#sign-in-interactively).

    ```ps1
    az login
    ```
1. [Upgrade the Azure CLI Bicep extension](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli).
    Run the following command to verify that you're running version 0.12.40 or higher.

    ```ps1
    az bicep version
    ```

1. [Install the Azure Dev CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd).
    Run the following command to verify that the Azure Dev CLI is installed.

    ```ps1
    azd auth login
    ```

1. [Install .NET 6 SDK](https://dotnet.microsoft.com/download/dotnet/6.0)
    Run the following command to verify that the .NET SDK 6.0 is installed.
    ```ps1
    dotnet --version
    ```

## Platform compatibility

|             |  Native   | DevContainer |
|-------------|-----------|--------------|
| Windows     |    ✅     |      ✅      |
| Windows WSL |    ✅     |      ✅      |
| macOS       |    ✅     |      ✅      |
| macOS arm64 |    ✅     |      ✅      |
| Linux       |    ✅     |      ✅      |

## VSCode DevContainer prerequisites

1. Docker Desktop
1. VSCode
1. VSCode ms-vscode-remote.remote-containers extension
1. git
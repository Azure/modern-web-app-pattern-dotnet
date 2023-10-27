# Known issues
This document helps with troubleshooting and provides an introduction to the most requested features, gotchas, and questions.

## Data consistency for multi-regional deployments

This sample includes a feature to deploy to two Azure regions. The feature is intended to support the high availability scenario by deploying resources in an active/passive configuration. The sample currently supports the ability to fail-over web-traffic so requests can be handled from a second region. However it does not support data synchronization between two regions. 

This can result in users losing trust in the system when they observe that the system is online but their data is missing. The following issues represent the work remaining to address data synchronization.

Open issues:
* [Implement multiregional Azure SQL](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/44)
* [Implement multiregional Storage](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/122)

## Troubleshooting
The following topics are intended to help readers with our most commonly reported issues.

* **Error: no project exists; to create a new project, run 'azd init'**
    This error is most often reported when users try to run `azd` commands before running the `cd` command to switch to the directory where the repo was cloned.

    > You may need to `cd` into the directory you cloned to run this command.

* **The deployment <azd-env-name> already exists in location**
    This error most often happens when trying a new region with the same for a deployment with the same name used for the AZD environment name (e.g. by default it would be `eapdotnetmwa`).

    When the `azd provision` command runs it creates a deployment resource in your subscription. You must delete this deployment before you can change the Azure region.

    > Assumes you are logged in with `az` cli.
    
    1. Find the name of the Deployment you want to delete
    
        ```sh
        az deployment sub list --query "[].name" -o tsv
        ```

    1. Delete the deployment by name

        ```sh
        az deployment sub delete -n <deployment-name>
        ```

    1. You should now be able to run the `azd provision` command and resume your deployment.

# GitHub Actions
GitHub Actions makes it easy to automate your software workflows with world-class CI/CD. You can build, test, and deploy your code right from GitHub.

In this directory you'll find files that you can use to get started with this sample in your repo and files that we use to maintain the quality of this sample by automating our test cycles.

## Sample workflows for your environment
The file `azure-release.yml` is one that you can use to configure this sample for continuous integration, testing, and deployment to example QA and Prod environments. To get started with this file you will want to uncomment the trigger section at the top which defines when this GitHub Action workflow should run.

To allow your GitHub Actions to perform deployments from your main branch, perform the following steps:
1. Install the GutHub CLI.
2. Clone your repository locally and navigate to the repository directory.
3. Run the following azd commands. Update `<PrincipalName>` to match your desired Service Principal name.
```azurecli
azd pipeline config --principal-name <PrincipalName> --principal-role "User Access Administrator"
```
1. Execute the following az cli commands to add additional trusts to allow deployment from GitHub environments named "QA" and "PROD". Update `<PrincipalName>` and `<REPO>` to match your GitHub repository, the REPO should be set to: GitHub_Organization/Repository_Name, an example for this repository would be: `Azure/modern-web-app-pattern-dotnet`.
```azurecli
appId=$(az ad app list --display-name <PrincipalName> --query [0].id -o tsv)
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${appId}/federatedIdentityCredentials" --body '{"name":"qa","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<REPO>:environment:QA","description":"QA Env","audiences":["api://AzureADTokenExchange"]}'
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${appId}/federatedIdentityCredentials" --body '{"name":"prod","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<REPO>:environment:PROD","description":"PROD Env","audiences":["api://AzureADTokenExchange"]}'
```

## Other considerations
Your devOps process should be customized to automate the build, test, and deployment steps specific to your business needs.

We recommend these following considerations to expand on the `azure-release.yml` sample.

- You may want to review `scheduled-azure-dev.yml` to see how to add more steps such as validation testing
- You may want multiple workflows defined in different files for different purposes
    - Consider database lifecycle management
    - Consider quality testing processes (e.g. integration testing)

## Engineering workflows
This repository also contains workflows that are part of our engineering process to ensure the quality of this sample. The following files are used by the team:

<!-- - `add-issues-to-project.yml`: Uses a GitHub Action to automate the process of adding an item that was created in this repository to our central project management board to improve visibility and work item tracking. -->
- `scheduled-azure-dev.yml`: Deploys the Azure resources in this sample so that we can check for quality characteristics and ensure that the latest tooling recommendation are compatible.
- `scheduled-azure-teardown.yml`: In the event of a workflow failure, we use this file to teardown any remaining Azure resources to limit the costs that accrue as part of our testing cycles.

### Validation Script
As part of this sample the dev team is monitoring for scenarios such as race conditions and intermittent issues which could cause the deployment to fail. As these issues are identified we update the `validateDeployment.sh`, and the mirror file `validateDeployment.ps1` which are also part of our engineering process. We use these files to validate characteristics of a successful deployment. These files will evolve as the sample evolves to help us ensure the quality of the solution.
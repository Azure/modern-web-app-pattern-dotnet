## Scripts by folder
- *devOpsScripts*: Scripts that are run by the GH pipeline to support deployment or validation of a deployment
- *deploymentScripts*: Scripts that are run in Azure as deployment scripts referenced in bicep to configure the Azure resources that are provisioned
- *localDevScripts*: Scripts that a developer uses to get access to Azure resources for local development workflows
- *prepareScripts*: Scripts that create the Azure AD App Registrations that this sample accepts as parameters to support reuse of App Registrations or using App Registrations created by an IT Administrator
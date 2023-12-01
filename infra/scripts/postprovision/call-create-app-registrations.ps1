# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.

$resourceGroupName=(azd env get-values --output json | ConvertFrom-Json).AZURE_RESOURCE_GROUP

./infra/scripts/predeploy/create-app-registrations.ps1 -ResourceGroup $resourceGroupName
# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.

#!/bin/bash
resourceGroupName=((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)

pwsh ./infra/scripts/predeploy/create-app-registrations.ps1 -ResourceGroup $resourceGroupName
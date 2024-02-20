#!/bin/bash

# This script is run by the azd pre-deploy hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.
resourceGroupName=$((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)

echo "Calling configure-aca-secrets.ps1 for group: '$resourceGroupName'..."

pwsh ./infra/scripts/predeploy/configure-aca-secrets.ps1 -ResourceGroupName $resourceGroupName -NoPrompt
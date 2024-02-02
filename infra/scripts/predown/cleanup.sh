#!/bin/bash

# This script is run by azd pre-down hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.
hubGroupName=$((azd env get-values --output json) | jq -r .hub_group_name)
subscriptionId=$((azd env get-values --output json) | jq -r .AZURE_SUBSCRIPTION_ID)

if [ -z "$hubGroupName" ]; then
  echo "Azure hub group name not found in environment variables. No cleanup needed. Exiting..."
else
    echo "Remove budget for group:'$hubGroupName'..."
    token=$(az account get-access-token --query accessToken -o tsv)
    apiVersion="?api-version=2023-05-01"
    restUri="https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$hubGroupName/providers/Microsoft.Consumption/budgets$apiVersion"

    authHeader="Bearer $token"
    result=$(curl -s -X GET -H "Authorization: $authHeader" $restUri)
    budgetName=$(echo $result | jq -r '.value[0].name')

    # use the AZ CLI to remove the budget
    echo "Remove budget named:'$budgetName'..."
    az consumption budget delete --budget-name $budgetName --resource-group $hubGroupName --subscription $subscriptionId
fi

# todo - remove diagnostic settings
# todo - remove app registration
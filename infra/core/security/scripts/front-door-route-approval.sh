#!/bin/bash

# This script approves pending private endpoint connections for Azure Web Apps.
# It retrieves the resource group name from the environment variable $ResourceGroupName.
# It then lists all the web apps in the specified resource group and retrieves their IDs.
# For each web app, it checks for pending private endpoint connections and approves them.
# The approval is done by calling the 'az network private-endpoint-connection approve' command.
# The description for the approval is set to "ApprovedByCli".
#
# Usage: ./front-door-route-approval.sh
#
# Prerequisites:
# - Azure CLI must be installed and logged in.
# - The environment variable $ResourceGroupName must be set to the desired resource group name.
#
# Note: This script requires appropriate permissions to approve private endpoint connections.

rg_name="$ResourceGroupName"
webapp_ids=$(az webapp list -g $rg_name --query "[].id" -o tsv)

# Validate that we found a front-end and back-end web app.
# When deploying multi-region, we expect to find 2 web apps as two resource groups are deployed.
if [[ $(echo "$webapp_ids" | wc -w) -ne 2 ]]; then
    echo "Invalid webapp_ids length. Expected 2, but found $(echo "$webapp_ids" | wc -w)"
    exit 1
fi

for webapp_id in $webapp_ids; do
    retry_count=0

    # Retrieve the pending private endpoint connections for the web app.
    # The front door pending private endpoint connections will be created asynchronously
    # so the retry has been added for this scenario to await the asynchronous operation.
    while [[ $retry_count -lt 5 ]]; do
        fd_conn_ids=$(az network private-endpoint-connection list --id $webapp_id --query "[?properties.provisioningState == 'Pending'].id" -o tsv)

        if [[ $(echo "$fd_conn_ids" | wc -w) -gt 0 ]]; then
            break
        fi

        retry_count=$((retry_count + 1))
        sleep 5
    done

    if [[ $retry_count -eq 5 ]]; then
        echo "Failed to retrieve pending private endpoint connections for web app with ID: $webapp_id"
        exit 1
    fi

    # Approve any pending private endpoint connections.
    for fd_conn_id in $fd_conn_ids; do
        az network private-endpoint-connection approve --id "$fd_conn_id" --description "ApprovedByCli"
    done
done

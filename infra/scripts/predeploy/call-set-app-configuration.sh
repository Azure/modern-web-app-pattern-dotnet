# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.

#!/bin/bash
pwsh ./infra/scripts/predeploy/set-app-configuration.ps1 
#Requires -Version 7.0

<#
.SYNOPSIS
    Builds and runs the Azure.LoadTest.Tool to validate the deployment of the web app.
.DESCRIPTION
    The Azure Load Test Service does not provide a way to run a load test from the command line.
    We built the Azure.LoadTest.Tool to upload a JMeter file, configure the test plan, associate
    server-side metrics, define environment variables, and run the load test.

    This workflow is intended to be seamlessly integrated with the AZD deploy operation which
    will start the load test at the first available opportunity. This also reduces the steps a
    reader needs to perform to tryout the sample.
#>

# Paths in this script are relative to the execution hooks specified in Azure.yml
# where this sccript will be invoked as part of the postdeploy process to start a
# load test after code has been deployed.

Write-Host 'Now building the tool...'

try {
    $pathToPublishFolder = "../../tools/Azure.LoadTest.Tool/publish"
    $pathToCsProj = "../../tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj"
    $process = Start-Process dotnet -ArgumentList "publish --output $pathToPublishFolder $pathToCsProj" -Wait -NoNewWindow -PassThru -ErrorAction Stop

    $timeout = New-TimeSpan -Seconds 60
    $process.WaitForExit($timeout.TotalMilliseconds)

    if ($process.ExitCode -ne 0) {
        throw "An dotnet publish exited with a non-zero exit code: $($process.ExitCode)"
    }
}
catch {
    throw "An error occurred during dotnet publish: $($_.Exception.Message)"
}

# Assumes the environment has already been created because this runs as part of the azd deploy process
$azdEnvironment = (azd env list --output json) | ConvertFrom-Json | Where-Object { $_.IsDefault -eq 'true' }
Write-Host "Discovered AZD environment: $($azdEnvironment.name)"

Write-Host 'Now running the Azure.LoadTest.Tool...'

try {
    $pathToTool = "../../tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe"
    $process = Start-Process $pathToTool -ArgumentList "--environment-name $($azdEnvironment.name)" -Wait -NoNewWindow -PassThru -ErrorAction Stop

    $loadTestTimeout = New-TimeSpan -Seconds 120
    $process.WaitForExit($loadTestTimeout)

    if ($process.ExitCode -ne 0) {
        throw "The load test tool app exited with a non-zero code: $($process.ExitCode)"
    }
}
catch {
    throw "An error occurred while running the load test tool app: $($_.Exception.Message)"
}
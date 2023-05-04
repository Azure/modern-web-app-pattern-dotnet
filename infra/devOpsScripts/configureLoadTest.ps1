## TODO: Add header

# Paths in this script are relative to the execution hooks specified in Azure.yml where this sccript will be invoked as part of the postdeploy process to start a load test after code has been deployed

Write-Host 'Now building the tool'

try {
    $pathToPublishFolder = "../../tools/Azure.LoadTest.Tool/publish"
    $pathToCsProj = "../../tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj"
    $process = Start-Process dotnet -ArgumentList "publish --output $pathToPublishFolder $pathToCsProj" -Wait -NoNewWindow -PassThru -ErrorAction Stop

    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "The build command exited with a non-zero code: $($process.ExitCode)"
    }
}
catch {
    throw "An error occurred while running the build command: $($_.Exception.Message)"
}

$azdEnvironment = (azd env list --output json) | ConvertFrom-Json | Where-Object { $_.IsDefault -eq 'true' }
Write-Host "Discovered AZD environment: $($azdEnvironment.name)"

Write-Host 'Now running the Azure.LoadTest.Tool...'

try {
    $pathToTool = "../../tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe"
    $process = Start-Process $pathToTool -ArgumentList "--environment-name $($azdEnvironment.name)" -Wait -NoNewWindow -PassThru -ErrorAction Stop

    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "The load test tool app exited with a non-zero code: $($process.ExitCode)"
    }
}
catch {
    throw "An error occurred while running the load test tool app: $($_.Exception.Message)"
}

if ($exitCodeForLoadTestTool -ne 0) {
    throw "Failed to complete the load test configuration"
}
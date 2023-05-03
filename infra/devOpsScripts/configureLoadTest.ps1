## TODO: Add header

# Paths in this script are relative to the execution hooks specified in Azure.yml where this sccript will be invoked as part of the postdeploy process to start a load test after code has been deployed

Write-Host 'Now building the tool'
$exitCodeForDotnetBuild = & "dotnet publish ../../tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj --output ../../tools/Azure.LoadTest.Tool/publish"
if ($exitCodeForDotnetBuild -ne 0) {
    throw "Failed to build the load test tool"
}

$azdEnvironment = (azd env list --output json) | ConvertFrom-Json | Where-Object { $_.IsDefault -eq 'true' }
Write-Host "Discovered AZD environment: ${azdEnvironment.name}"

Write-Host 'Now running the Azure.LoadTest.Tool...'
$exitCodeForLoadTestTool = & "../../tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe --environment-name $azdEnvironment.name"

if ($exitCodeForLoadTestTool -ne 0) {
    throw "Failed to complete the load test configuration"
}
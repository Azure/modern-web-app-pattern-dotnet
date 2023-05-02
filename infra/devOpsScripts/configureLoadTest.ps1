## TODO: Add header

Write-Host 'Now building the tool'
dotnet publish ./tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj --output ./tools/Azure.LoadTest.Tool/publish

$azdEnvironment = (azd env list --output json) | ConvertFrom-Json | Where-Object { $_.IsDefault -eq 'true' }
Write-Host "Discovered AZD environment: ${azdEnvironment.name}"

Write-Host 'Now running the Azure.LoadTest.Tool...'
./tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe --environment-name $azdEnvironment.name
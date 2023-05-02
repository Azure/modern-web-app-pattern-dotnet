#!/bin/bash

## TODO: Add header

echo 'Now building the tool'
dotnet publish ./tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj --output ./tools/Azure.LoadTest.Tool/publish

# TODO: fix this hard coded value
azdEnvironmentName=relekendev3
echo "Discovered AZD environment: $azdEnvironmentName"

echo 'Now running the Azure.LoadTest.Tool...'
./tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe --environment-name $azdEnvironmentName
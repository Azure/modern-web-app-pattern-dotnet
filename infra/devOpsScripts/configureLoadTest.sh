#!/bin/bash

################################################################################################
# The Azure Load Test Service does not provide a way to run a load test from the command line.
# We built the Azure.LoadTest.Tool to upload a JMeter file, configure the test plan, associate
# server-side metrics, define environment variables, and run the load test.
# 
# This workflow is intended to be seamlessly integrated with the AZD deploy operation which
# will start the load test at the first available opportunity. This also reduces the steps a
# reader needs to perform to tryout the sample.
################################################################################################

echo 'Now building the tool'
dotnet publish ./tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj --output ./tools/Azure.LoadTest.Tool/publish

# TODO: fix this hard coded value
azdEnvironmentName=relekendev3
echo "Discovered AZD environment: $azdEnvironmentName"

echo 'Now running the Azure.LoadTest.Tool...'
./tools/Azure.LoadTest.Tool/publish/Azure.LoadTest.Tool.exe --environment-name $azdEnvironmentName
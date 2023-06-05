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

echo 'Now building the tool...'
csproj_path="../../tools/Azure.LoadTest.Tool/Azure.LoadTest.Tool/Azure.LoadTest.Tool.csproj"
publish_path="../../tools/Azure.LoadTest.Tool/publish"
nohup dotnet publish "$csproj_path" --output "$publish_path" > dotnet_publish.log 2>&1 &

PID=$!
wait $PID

if [ $? -ne 0 ]; then
    echo "An error occurred during dotnet publish. The file dotnet_publish.log has more details." >&2
    exit 1
fi

# Assumes the environment has already been created because this runs as part of the azd deploy process
azdEnvironmentName=$(azd env list | grep -w true | awk '{print $1}')
echo "Discovered AZD environment: $azdEnvironmentName"

echo 'Now running the Azure.LoadTest.Tool...'
nohup "$publish_path/Azure.LoadTest.Tool.exe" --environment-name "$azdEnvironmentName" > loadtest_tool.log 2>&1 &

PID=$!
wait $PID

if [ $? -eq 0 ]; then
    echo "An error occurred while running the load test tool app. The file loadtest_tool.log has more details."
    
    echo ""
    echo "loadtest_tool.log contents:"
    cat loadtest_tool.log
    
    echo ""
    echo "log.txt contents:"
    cat log.txt
else
    echo "Command failed with exit code $?."
fi

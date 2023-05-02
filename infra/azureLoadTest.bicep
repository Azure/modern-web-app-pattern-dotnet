@description('A generated identifier used to create unique resources')
param resourceToken string

@description('The Azure location where this solution is deployed')
param location string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

resource loadTestService 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: 'lt-${resourceToken}-loadTests'
  location: location
  tags: tags
  properties: {
    description: 'Load Test Service that executes JMeter scripts to measure the performance impact of changes to a web application'
  }
}

output loadTestServiceName string = loadTestService.name

// path to the file name will be relative to the tool that uploads the file
// the default tool used to upload the file is {repoRoot}/tools/Azure.LoadTest.Tool/bin/Debug/net7.0/Azure.LoadTest.Tool.exe
output loadTestFileName string = 'basic-test.jmx'

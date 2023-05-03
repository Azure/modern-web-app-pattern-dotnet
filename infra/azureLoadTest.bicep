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

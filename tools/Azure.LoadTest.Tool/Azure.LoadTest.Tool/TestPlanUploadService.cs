using Azure.LoadTest.Tool.Models.AzureLoadTest;
using Azure.LoadTest.Tool.Operators;
using Microsoft.Extensions.Logging;

namespace Azure.LoadTest.Tool
{
    public class TestPlanUploadService
    {
        private ILogger<TestPlanUploadService> _logger;
        private AzdOperator _azdOperator;
        private AzureLoadTestDataPlaneOperator _altOperator;
        private AzureResourceManagerOperator _azureOperator;

        public TestPlanUploadService(
            ILogger<TestPlanUploadService> logger,
            AzdOperator azdOperator,
            AzureLoadTestDataPlaneOperator altOperator,
            AzureResourceManagerOperator azureOperator)
        {
            _logger = logger;
            _azdOperator = azdOperator;
            _altOperator = altOperator;
            _azureOperator = azureOperator;
        }

        public async Task CreateTestPlanAsync(CancellationToken cancellationToken)
        {
            string subscriptionId = _azdOperator.GetSubscriptionId();
            string resourceGroupName = _azdOperator.GetResourceGroupName();
            string loadTestName = _azdOperator.GetAzureLoadTestServiceName();
            string domainName = _azdOperator.GetEnvironmentVarDomainName();
            string pathToJmx = _azdOperator.GetPathToJMeterFile();

            _logger.LogInformation($"Working with subscriptionId: {subscriptionId}");
            _logger.LogInformation($"Looking for resourceGroupName: {resourceGroupName}");
            _logger.LogInformation($"Configuring loadTestName: {loadTestName}");

            var dataPlaneUri = await _azureOperator.GetAzureLoadTestDataPlaneUriAsync(subscriptionId, resourceGroupName, loadTestName, cancellationToken);

            _logger.LogInformation($"Found the dataPlaneUri: {dataPlaneUri}");

            var testId = await _altOperator.CreateLoadTestAsync(dataPlaneUri, domainName, cancellationToken);

            _logger.LogInformation($"Created testId: {testId}");

            await _altOperator.UploadTestFileAsync(dataPlaneUri, testId, pathToJmx, cancellationToken);

            var resourceIds = _azdOperator.GetAzureLoadTestAppComponentsResourceIds();
            
            var appComponents = new List<ComponentInfo>();
            foreach (var resourceId in  resourceIds)
            {
                var resourceDetails = await _azureOperator.GetResourceByIdAsync(resourceId, cancellationToken);

                appComponents.Add(new ComponentInfo
                {
                    ResourceId = resourceId,
                    Kind = resourceDetails.Kind,
                     ResourceGroup = resourceGroupName,
                     ResourceName = resourceDetails.Name,
                     ResourceType = resourceDetails.ResourceType,
                     SubscriptionId = subscriptionId
                });
            }

            await _altOperator.AssociateAppComponentsAsync(dataPlaneUri, testId, appComponents, cancellationToken);

            await _altOperator.StartLoadTestAsync(dataPlaneUri, testId, domainName, cancellationToken);
        }
    }
}

using Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.Logging;

namespace Azure.LoadTest.Tool
{
    public class TestPlanUploadService
    {
        private ILogger<TestPlanUploadService> _logger;
        private AzdParametersProvider _azdOperator;
        private AzureLoadTestDataPlaneOperator _altOperator;
        private AzureResourceManagerOperator _azureOperator;

        public TestPlanUploadService(
            ILogger<TestPlanUploadService> logger,
            AzdParametersProvider azdOperator,
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
            var subscriptionId = _azdOperator.GetSubscriptionId();
            var resourceGroupName = _azdOperator.GetResourceGroupName();
            var loadTestName = _azdOperator.GetAzureLoadTestServiceName();
            var pathToJmx = _azdOperator.GetPathToJMeterFile();

            _logger.LogInformation($"Working with subscriptionId: {subscriptionId}");
            _logger.LogInformation($"Looking for resourceGroupName: {resourceGroupName}");
            _logger.LogInformation($"Configuring loadTestName: {loadTestName}");

            var dataPlaneUri = await GetAzureLoadTestDataPlaneUri(resourceGroupName, loadTestName, cancellationToken);

            _logger.LogInformation($"Found the dataPlaneUri: {dataPlaneUri}");

            var testId = await _altOperator.CreateLoadTestAsync(dataPlaneUri);

            _logger.LogInformation($"Created testId: {testId}");

            await _altOperator.UploadTestFileAsync(dataPlaneUri, testId, pathToJmx);

            var resourceIds = _azdOperator.GetAzureLoadTestAppComponentsResourceIds();

            var appComponents = new List<AppComponentInfo>();
            foreach (var resourceId in resourceIds)
            {
                var resourceDetails = await _azureOperator.GetResourceByIdAsync(resourceId, cancellationToken);

                appComponents.Add(new AppComponentInfo
                {
                    ResourceId = resourceId,
                    Kind = resourceDetails.Kind,
                    ResourceGroup = resourceGroupName,
                    ResourceName = resourceDetails.Name,
                    ResourceType = resourceDetails.Type,
                    SubscriptionId = subscriptionId
                });
            }

            await _altOperator.AssociateAppComponentsAsync(dataPlaneUri, testId, appComponents);

            await _altOperator.StartLoadTestAsync(dataPlaneUri, testId);
        }

        private async Task<string> GetAzureLoadTestDataPlaneUri(string resourceGroupName, string loadTestName, CancellationToken cancellationToken)
        {
            var azureLoadTestResource = await _azureOperator.GetAzureLoadTestByNameAsync(resourceGroupName, loadTestName, cancellationToken);

            var stringProperties = (Dictionary<string, object>)azureLoadTestResource.Properties;

            var dataPlaneUri = stringProperties["dataPlaneURI"].ToString();
            if (string.IsNullOrEmpty(dataPlaneUri))
            {
                throw new ArgumentNullException(nameof(dataPlaneUri));
            }

            return dataPlaneUri;
        }
    }
}

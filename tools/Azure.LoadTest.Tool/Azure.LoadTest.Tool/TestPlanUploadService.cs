using Azure.LoadTest.Tool.Mappers;
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
        private AppComponentsMapper _appComponentsMapper;

        public TestPlanUploadService(
            ILogger<TestPlanUploadService> logger,
            AzdParametersProvider azdOperator,
            AzureLoadTestDataPlaneOperator altOperator,
            AzureResourceManagerOperator azureOperator,
            AppComponentsMapper appComponentsMapper)
        {
            _logger = logger;
            _azdOperator = azdOperator;
            _altOperator = altOperator;
            _azureOperator = azureOperator;
            _appComponentsMapper = appComponentsMapper;
        }

        public async Task CreateTestPlanAsync(CancellationToken cancellation)
        {
            var subscriptionId = _azdOperator.GetSubscriptionId();
            var resourceGroupName = _azdOperator.GetResourceGroupName();
            var loadTestName = _azdOperator.GetAzureLoadTestServiceName();
            var pathToJmx = _azdOperator.GetPathToJMeterFile();

            _logger.LogDebug("Working with subscriptionId: {subscriptionId}", subscriptionId);
            _logger.LogDebug("Looking for resourceGroupName: {resourceGroupName}", resourceGroupName);
            _logger.LogDebug("Configuring loadTestName: {loadTestName}", loadTestName);

            var dataPlaneUri = await GetAzureLoadTestDataPlaneUriAsync(resourceGroupName, loadTestName, cancellation);

            _logger.LogDebug("Found the dataPlaneUri: {dataPlaneUri}", dataPlaneUri);

            var testId = await _altOperator.CreateLoadTestAsync(dataPlaneUri);

            _logger.LogDebug("Created testId: {testId}", testId);

            await _altOperator.UploadTestFileAsync(dataPlaneUri, testId, pathToJmx);

            var azureResourceIds = _azdOperator.GetAzureLoadTestAppComponentsResourceIds();

            var appComponents = await _appComponentsMapper.MapComponentsAsync(azureResourceIds, cancellation);

            await _altOperator.AssociateAppComponentsAsync(dataPlaneUri, testId, appComponents);

            await _altOperator.StartLoadTestAsync(dataPlaneUri, testId);
        }

        private async Task<string> GetAzureLoadTestDataPlaneUriAsync(string resourceGroupName, string loadTestName, CancellationToken cancellationToken)
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

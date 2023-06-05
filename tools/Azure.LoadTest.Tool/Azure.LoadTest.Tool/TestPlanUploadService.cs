using Azure.LoadTest.Tool.Mappers;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

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
            _logger.LogDebug("Retrieved subscriptionId: {subscriptionId}", subscriptionId);

            var resourceGroupName = _azdOperator.GetResourceGroupName();
            _logger.LogDebug("Retrieved resourceGroupName: {resourceGroupName}", resourceGroupName);

            var loadTestName = _azdOperator.GetAzureLoadTestServiceName();
            _logger.LogDebug("Retrieved loadTestName: {loadTestName}", loadTestName);

            var pathToJmx = _azdOperator.GetPathToJMeterFile();
            if (Debugger.IsAttached)
            {
                // overrides AZD environment path which will not match the context
                // when executing from Visual Studio
                pathToJmx = "basic-test.jmx";
            }
            _logger.LogDebug("Retrieved pathToJmx: {pathToJmx}", pathToJmx);

            _logger.LogInformation("Retrieving dataPlaneUri");
            var dataPlaneUri = await GetAzureLoadTestDataPlaneUriAsync(resourceGroupName, loadTestName, cancellation);
            _logger.LogInformation("DataPlaneUri: {dataPlaneUri}", dataPlaneUri);

            var testId = await _altOperator.CreateLoadTestAsync(dataPlaneUri);

            _logger.LogInformation("Created testId: {testId}", testId);

            await _altOperator.UploadTestFileAsync(dataPlaneUri, testId, pathToJmx);

            var azureResourceIds = _azdOperator.GetAzureLoadTestAppComponentsResourceIds();

            var appComponents = await _appComponentsMapper.MapComponentsAsync(azureResourceIds, cancellation);

            _logger.LogInformation("Associating components for testId: {testId}", testId);
            await _altOperator.AssociateAppComponentsAsync(dataPlaneUri, testId, appComponents);

            _logger.LogInformation("Starting testId: {testId}", testId);
            await _altOperator.StartLoadTestAsync(dataPlaneUri, testId);

            _logger.LogInformation("Test was successfully started");
        }

        private async Task<string> GetAzureLoadTestDataPlaneUriAsync(string resourceGroupName, string loadTestName, CancellationToken cancellation)
        {
            var azureLoadTestResource = await _azureOperator.GetAzureLoadTestByNameAsync(resourceGroupName, loadTestName, cancellation);

            _logger.LogDebug("Retrieved ALT resource: {id}", azureLoadTestResource.Id);

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

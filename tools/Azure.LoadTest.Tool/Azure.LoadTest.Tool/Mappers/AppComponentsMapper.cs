using Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.Logging;

namespace Azure.LoadTest.Tool.Mappers
{
    public class AppComponentsMapper
    {
        private readonly AzureResourceManagerOperator _azureOperator;
        private readonly AzdParametersProvider _azdParametersProvider;
        private readonly ILogger<AppComponentsMapper> _logger;

        /// <summary>
        /// A utility to perform mapping from resourceId strings into fully hydrated AppComponentInfo objects
        /// that will be sent to the Azure Load Test Service's API
        /// </summary>
        public AppComponentsMapper(
            AzureResourceManagerOperator azureOperator,
            AzdParametersProvider azdParametersProvider,
            ILogger<AppComponentsMapper> logger)
        {
            _azureOperator = azureOperator;
            _azdParametersProvider = azdParametersProvider;
            _logger = logger;
        }

        public async Task<Dictionary<string, AppComponentInfo>> MapComponentsAsync(IEnumerable<string> resourceIds, CancellationToken cancellation)
        {
            var resourceGroupName = _azdParametersProvider.GetResourceGroupName();
            _logger.LogDebug("ResourceGroupName: {resourceGroupName}", resourceGroupName);
            var subscriptionId = _azdParametersProvider.GetSubscriptionId();
            _logger.LogDebug("SubscriptionId: {subscriptionId}", subscriptionId);

            var appComponents = new Dictionary<string, AppComponentInfo>();
            foreach (var resourceId in resourceIds)
            {
                var resourceDetails = await _azureOperator.GetResourceByIdAsync(resourceId, cancellation);
                var appComponentInfo = new AppComponentInfo
                {
                    ResourceId = resourceId,
                    Kind = resourceDetails.Kind,
                    ResourceGroup = resourceGroupName,
                    ResourceName = resourceDetails.Name,
                    ResourceType = resourceDetails.Type,
                    SubscriptionId = subscriptionId
                };

                appComponents.TryAdd(resourceId, appComponentInfo);
            }

            return appComponents;
        }
    }
}

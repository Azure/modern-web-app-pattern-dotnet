using Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;

namespace Azure.LoadTest.Tool.Mappers
{
    public class AppComponentsMapper
    {
        private readonly AzureResourceManagerOperator _azureOperator;
        private readonly AzdParametersProvider _azdParametersProvider;

        /// <summary>
        /// A utility to perform mapping from resourceId strings into fully hydrated AppComponentInfo objects
        /// that will be sent to the Azure Load Test Service's API
        /// </summary>
        public AppComponentsMapper(
            AzureResourceManagerOperator azureOperator,
            AzdParametersProvider azdParametersProvider)
        {
            _azureOperator = azureOperator;
            _azdParametersProvider = azdParametersProvider;
        }

        public async Task<Dictionary<string, AppComponentInfo>> MapComponentsAsync(IEnumerable<string> resourceIds, CancellationToken cancellation)
        {
            var resourceGroupName = _azdParametersProvider.GetResourceGroupName();
            var subscriptionId = _azdParametersProvider.GetSubscriptionId();

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

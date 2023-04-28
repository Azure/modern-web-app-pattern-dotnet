using Azure.Identity;
using Azure.LoadTest.Tool.Providers;
using Azure.ResourceManager.Resources;
using Azure.ResourceManager.Resources.Models;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzureResourceManagerOperator
    {
        private readonly AzdParametersProvider _azdOperator;

        private ResourcesManagementClient? _client;

        public AzureResourceManagerOperator(
            AzdParametersProvider azdOperator)
        {
            _azdOperator = azdOperator;
        }

        private ResourcesManagementClient GetResourceClient()
        {
            if (_client == null)
            {
                var subscriptionId = _azdOperator.GetSubscriptionId();
                _client = new ResourcesManagementClient(subscriptionId, new DefaultAzureCredential());
            }

            return _client;
        }

        public Task<GenericResource> GetAzureLoadTestByNameAsync(string resourceGroupName, string loadTestServiceName, CancellationToken cancellation)
        {
            var subscriptionId = _azdOperator.GetSubscriptionId();
            var resourceId = $"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.LoadTestService/loadTests/{loadTestServiceName}";

            return GetResourceByIdAsync(resourceId, cancellation);
        }

        public async Task<GenericResource> GetResourceByIdAsync(string resourceId, CancellationToken cancellation)
        {
            var formattedResourceId = resourceId;
            if (!formattedResourceId.StartsWith("/"))
            {
                formattedResourceId = "/" + formattedResourceId;
            }

            var genericResourceResponse = await GetResourceClient().Resources.GetByIdAsync(formattedResourceId, GetApiVersionForProvider(resourceId), cancellation);
            ThrowIfError(genericResourceResponse);

            return genericResourceResponse.Value ?? throw new ArgumentNullException($"Unable to retrieve the azure resource with id: {resourceId}");


            string GetApiVersionForProvider(string resourceId)
            {
                const string DEFAULT_API_VERSION = "2020-02-02";
                if (string.IsNullOrEmpty(resourceId))
                {
                    return DEFAULT_API_VERSION;
                }

                // API specific for Azure App Service
                if (resourceId.Contains("Microsoft.Web/sites", StringComparison.Ordinal))
                {
                    return "2022-09-01";
                }

                if (resourceId.Contains("Microsoft.LoadTestService", StringComparison.Ordinal))
                {
                    return "2022-12-01";
                }

                // API specific for App Insights
                if (resourceId.Contains("microsoft.insights/components", StringComparison.Ordinal))
                {
                    return "2020-02-02";
                }

                return DEFAULT_API_VERSION;
            }
        }

        private static void ThrowIfError(Response<GenericResource> genericResourceResponse)
        {
            if (genericResourceResponse.GetRawResponse().IsError)
            {
                var errorReason = genericResourceResponse.GetRawResponse().ReasonPhrase;
                if (string.IsNullOrEmpty(errorReason))
                {
                    throw new InvalidOperationException("Could not deserialize error response received from Azure Management API");
                }

                throw new InvalidOperationException(errorReason);
            }
        }
    }
}

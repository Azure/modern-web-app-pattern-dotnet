using Azure.Identity;
using Azure.LoadTest.Tool.Mappers;
using Azure.LoadTest.Tool.Providers;
using Azure.ResourceManager.Resources;
using Azure.ResourceManager.Resources.Models;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzureResourceManagerOperator
    {
        private readonly AzdParametersProvider _azdOperator;
        private readonly AzureResourceApiMapper _apiMapper;

        private ResourcesManagementClient? _client;

        public AzureResourceManagerOperator(
            AzdParametersProvider azdOperator,
            AzureResourceApiMapper apiMapper)
        {
            _azdOperator = azdOperator;
            _apiMapper = apiMapper;
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

            var apiVersion = _apiMapper.GetApiForAzureResourceProvider(formattedResourceId);
            var genericResourceResponse = await GetResourceClient().Resources.GetByIdAsync(formattedResourceId, apiVersion, cancellation);
            ThrowIfError(genericResourceResponse);

            return genericResourceResponse.Value ?? throw new ArgumentNullException($"Unable to retrieve the azure resource with id: {resourceId}");
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

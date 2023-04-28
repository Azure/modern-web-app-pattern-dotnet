using Azure.Identity;
using Azure.LoadTest.Tool.Models.AzureManagement;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzureResourceManagerOperator
    {
        public async Task<string> GetAzureLoadTestDataPlaneUriAsync(string subscriptionId, string resourceGroupName, string loadTestName, CancellationToken cancellation)
        {
            var credential = new DefaultAzureCredential();
            var token = credential.GetToken(
                new Azure.Core.TokenRequestContext(new[] { "https://management.core.windows.net" }));

            var url = $"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.LoadTestService/loadTests/{loadTestName}?api-version=2022-12-01";
            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            HttpResponseMessage response = await client.GetAsync(url, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                var error = JsonSerializer.Deserialize<AzureManagementApiErrorResponse>(endpointMessage);
                if (string.IsNullOrEmpty(error?.Error?.Message))
                {
                    throw new InvalidOperationException("Could not deserialize error response received from Azure Management API");
                }

                throw new InvalidOperationException(error.Error.Message);
            }

            var altResource = JsonSerializer.Deserialize<AzureLoadTestResource>(endpointMessage);
            return altResource?.Properties?.DataPlaneURI ?? throw new ArgumentNullException($"Unable to retrieve the DataPlaneURI for the Azure Load Test Resource {loadTestName}");
        }

        public async Task<AzureResourceResponse> GetResourceByIdAsync(string resourceId, CancellationToken cancellation)
        {
            // GET 
            var credential = new DefaultAzureCredential();
            var token = credential.GetToken(
                new Azure.Core.TokenRequestContext(new[] { "https://management.core.windows.net" }));

            var formattedResourceId = resourceId;
            if (!formattedResourceId.StartsWith("/"))
            {
                formattedResourceId = "/" + formattedResourceId;
            }

            var providerSpecificApiVersion = GetApiVersionForProvider(resourceId);

            var url = $"https://management.azure.com{formattedResourceId}?api-version={providerSpecificApiVersion}";
            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            HttpResponseMessage response = await client.GetAsync(url, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                var error = JsonSerializer.Deserialize<AzureManagementApiErrorResponse>(endpointMessage);
                if (string.IsNullOrEmpty(error?.Error?.Message))
                {
                    throw new InvalidOperationException("Could not deserialize error response received from Azure Management API");
                }

                throw new InvalidOperationException(error.Error.Message);
            }

            var azureResource = JsonSerializer.Deserialize<AzureResourceResponse>(endpointMessage);
            return azureResource ?? throw new ArgumentNullException($"Unable to retrieve the azure resource with id: {resourceId}");


            string GetApiVersionForProvider(string resourceId)
            {
                const string DEFAULT_API_VERSION = "2020-02-02";
                if (string.IsNullOrEmpty(resourceId))
                {
                    return DEFAULT_API_VERSION;
                }

                // API specific for Azure App Service
                if (resourceId.Contains("Microsoft.Web/sites", StringComparison.OrdinalIgnoreCase))
                {
                    return "2022-09-01";
                }

                // API specific for App Insights
                if (resourceId.Contains("microsoft.insights/components", StringComparison.OrdinalIgnoreCase))
                {
                    return "2020-02-02";
                }

                return DEFAULT_API_VERSION;
            }
        }
    }
}

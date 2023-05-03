namespace Azure.LoadTest.Tool.Mappers
{
    /// <summary>
    /// Each azure resource provider specifies a unique API version that is a required parameter
    /// that must be sent when retrieving an Azure resource. This mapper examines the resourceId
    /// string and provides the API version that maps to the resourceId.
    /// </summary>
    public class AzureResourceApiMapper
    {
        /// <summary>
        /// Supports locating the API by resource provider, and by fully populated resourceId
        /// </summary>
        /// <param name="resourceId">An azure resourceId similar to: /subscriptions/{Guid}/resourceGroups/{string}/providers/{azure_resource_provider}/{string}</param>
        /// <exception cref=""
        /// <returns>an API version string similar to: "2022-09-01"</returns>
        /// <exception cref="InvalidOperationException">thrown when the API version could not be found for the specified {resourceId}</exception>
        public string GetApiForAzureResourceProvider(string resourceId)
        {
            if (string.IsNullOrEmpty(resourceId))
            {
                throw new InvalidOperationException("Azure resourceId was not specified");
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

            throw new InvalidOperationException("Unsupported Azure resource type");
        }
    }
}

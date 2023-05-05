using Microsoft.Extensions.Logging;

namespace Azure.LoadTest.Tool.Mappers
{
    /// <summary>
    /// Each azure resource provider specifies a unique API version that is a required parameter
    /// that must be sent when retrieving an Azure resource. This mapper examines the resourceId
    /// string and provides the API version that maps to the resourceId.
    /// </summary>
    public class AzureResourceApiMapper
    {
        private readonly ILogger<AzureResourceApiMapper> _logger;

        public AzureResourceApiMapper(ILogger<AzureResourceApiMapper> logger)
        {
            _logger = logger;
        }

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
                _logger.LogError("It's not supposed to be null");
                throw new InvalidOperationException("Azure resourceId was not specified");
            }

            if (resourceId.Contains("Microsoft.Web/sites", StringComparison.OrdinalIgnoreCase))
            {
                const string APP_SERVICE_API = "2022-09-01";
                _logger.LogDebug("Using api {api} for {resourceProvider}", APP_SERVICE_API, "Microsoft.Web/sites");
                return APP_SERVICE_API;
            }

            if (resourceId.Contains("Microsoft.LoadTestService", StringComparison.OrdinalIgnoreCase))
            {
                const string ALT_SERVICE_API = "2022-12-01";
                _logger.LogDebug("Using api {api} for {resourceProvider}", ALT_SERVICE_API, "Microsoft.LoadTestService");
                return ALT_SERVICE_API;
            }

            if (resourceId.Contains("Microsoft.Insights/components", StringComparison.OrdinalIgnoreCase))
            {
                const string APP_INSIGHTS_API = "2020-02-02";
                _logger.LogDebug("Using api {api} for {resourceProvider}", APP_INSIGHTS_API, "Microsoft.Insights/components");
                return APP_INSIGHTS_API;
            }

            _logger.LogError("The resource {resourceId} was not recognized", resourceId);
            throw new InvalidOperationException($"Unsupported Azure resource type: {resourceId}");
        }
    }
}

using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class AppComponentInfo
    {
        [JsonPropertyName("resourceId")]
        public string? ResourceId { get; set; }

        [JsonPropertyName("resourceName")]
        public string? ResourceName { get; set; }

        [JsonPropertyName("resourceType")]
        public string? ResourceType { get; set; }

        [JsonPropertyName("resourceGroup")]
        public string? ResourceGroup { get; set; }

        [JsonPropertyName("subscriptionId")]
        public string? SubscriptionId { get; set; }

        [JsonPropertyName("kind")]
        public string? Kind { get; set; }
    }
}

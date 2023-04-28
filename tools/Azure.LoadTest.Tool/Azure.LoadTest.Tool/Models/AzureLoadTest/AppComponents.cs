using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class AssociateAppComponentsRequest
    {
        [JsonPropertyName("testId")]
        public Guid TestId { get; set; }

        [JsonPropertyName("components")]
        public Dictionary<string, ComponentInfo> Components { get; set; } = new Dictionary<string, ComponentInfo>();
    }

    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class AssociateAppComponentsResponse : AssociateAppComponentsRequest
    {
        [JsonPropertyName("lastModifiedBy")]
        public string? LastModifiedBy { get; set; }
    }

    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class ComponentInfo
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

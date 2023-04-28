using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class AssociateAppComponentsRequest
    {
        [JsonPropertyName("testId")]
        public Guid TestId { get; set; }

        [JsonPropertyName("components")]
        public Dictionary<string, AppComponentInfo> Components { get; set; } = new Dictionary<string, AppComponentInfo>();
    }
}

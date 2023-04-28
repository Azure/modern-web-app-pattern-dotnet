using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement
{
    public class AzureResourceResponse
    {
        [JsonPropertyName("id")]
        public string? Id { get; set; }

        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("kind")]
        public string? Kind { get; set; }

        [JsonPropertyName("type")]
        public string? ResourceType { get; set; }
    }
}

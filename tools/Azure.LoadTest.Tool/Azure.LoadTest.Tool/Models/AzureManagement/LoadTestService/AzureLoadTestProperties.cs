using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement.LoadTestService
{
    public class AzureLoadTestProperties
    {
        [JsonPropertyName("dataPlaneURI")]
        public string? DataPlaneURI { get; set; }
    }
}

using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement.LoadTestService
{
    public class AzureLoadTestResourceResponse
    {
        [JsonPropertyName("properties")]
        public AzureLoadTestProperties? Properties { get; set; }
    }
}

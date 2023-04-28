using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest
{
    public class TestRunResponse
    {
        [JsonPropertyName("testId")]
        public string? TestId { get; set; }

        [JsonPropertyName("testRunId")]
        public string? TestRunId { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("testResult")]
        public string? TestResult { get; set; }

        [JsonPropertyName("displayName")]
        public string? DisplayName { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("portalUrl")]
        public string? PortalUrl { get; set; }
    }
}

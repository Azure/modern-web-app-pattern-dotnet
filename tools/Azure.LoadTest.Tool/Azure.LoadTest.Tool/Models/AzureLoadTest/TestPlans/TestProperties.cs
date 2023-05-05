using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.TestPlans
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class TestProperties
    {
        [JsonPropertyName("testId")]
        public Guid TestId { get; set; } = Guid.NewGuid();

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("displayName")]
        public string? DisplayName { get; set; }

        [JsonPropertyName("loadTestConfiguration")]
        public LoadTestConfiguration LoadTestConfiguration { get; set; } = new LoadTestConfiguration();

        [JsonPropertyName("environmentVariables")]
        public Dictionary<string, string> EnvironmentVariables { get; set; } = new Dictionary<string, string>();
    }
}

using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest
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
        public EnvironmentVariables EnvironmentVariables { get; set; } = new EnvironmentVariables();
    }

    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class LoadTestConfiguration
    {
        [JsonPropertyName("engineInstances")]
        public int EngineInstances { get; set; } = 1;

        [JsonPropertyName("splitAllCSVs")]
        public bool SplitAllCSVs { get; set; }
    }

    // This suffices for MVP. As a general purpose tool we'll need a different
    // way to set environment variables to be more flexible.

    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class EnvironmentVariables
    {
        [JsonPropertyName("domain")]
        public string? Domain { get; set; }

        [JsonPropertyName("duration_in_sec")]
        public int DurationInSec { get; set; } = 120;

        [JsonPropertyName("protocol")]
        public string Protocol { get; set; } = "https";

        [JsonPropertyName("ramp_up_time")]
        public int RampUpTimeInSec { get; set; } = 10;

        [JsonPropertyName("threads_per_engine")]
        public int ThreadsPerEngine { get; set; } = 5;
    }

}

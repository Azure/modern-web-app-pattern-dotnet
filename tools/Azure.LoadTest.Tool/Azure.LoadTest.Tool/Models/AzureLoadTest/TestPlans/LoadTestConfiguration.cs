using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.TestPlans
{
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
}

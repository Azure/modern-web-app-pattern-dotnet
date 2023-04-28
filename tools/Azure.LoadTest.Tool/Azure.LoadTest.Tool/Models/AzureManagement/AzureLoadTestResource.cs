using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement
{
    internal class AzureLoadTestResource
    {
        [JsonPropertyName("properties")]
        public AzureLoadTestProperties? Properties { get; set; }
    }

    internal class AzureLoadTestProperties
    {
        [JsonPropertyName("dataPlaneURI")]
        public string? DataPlaneURI { get; set; }
    }

    public class AzureManagementApiErrorResponse
    {
        [JsonPropertyName("error")]
        public ErrorDetail? Error { get; set; }
    }

    public class ErrorDetail
    {
        [JsonPropertyName("code")]
        public string? Code { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }
}

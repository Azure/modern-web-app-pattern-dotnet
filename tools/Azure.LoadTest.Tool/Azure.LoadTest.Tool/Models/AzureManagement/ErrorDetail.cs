using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement
{
    public class ErrorDetail
    {
        [JsonPropertyName("code")]
        public string? Code { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }
}

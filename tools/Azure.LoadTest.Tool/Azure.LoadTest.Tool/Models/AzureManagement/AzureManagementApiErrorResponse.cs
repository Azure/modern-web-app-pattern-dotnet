using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureManagement
{
    public class AzureManagementApiErrorResponse
    {
        [JsonPropertyName("error")]
        public ErrorDetail? Error { get; set; }
    }
}

using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class AssociateAppComponentsResponse : AssociateAppComponentsRequest
    {
        [JsonPropertyName("lastModifiedBy")]
        public string? LastModifiedBy { get; set; }
    }
}

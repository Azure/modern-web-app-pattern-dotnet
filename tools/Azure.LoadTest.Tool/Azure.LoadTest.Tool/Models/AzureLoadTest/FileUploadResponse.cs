using System.Text.Json.Serialization;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest
{
    public class FileUploadResponse
    {
        [JsonPropertyName("fileType")]
        public string? FileType { get; set; }

        [JsonPropertyName("expireDateTime")]
        public DateTime ExpireDateTime { get; set; }

        [JsonPropertyName("validationStatus")]
        public string? ValidationStatus { get; set; }

        [JsonPropertyName("fileName")]
        public string? FileName { get; set; }

        [JsonPropertyName("url")]
        public string? Url { get; set; }
    }

}

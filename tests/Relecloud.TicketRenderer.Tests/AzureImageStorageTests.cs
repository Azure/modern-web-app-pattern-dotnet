using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace Relecloud.TicketRenderer.Tests;

public class AzureImageStorageTests
{
    [Fact]
    public async Task StoreImageAsync_CallsBlobUploadWithCorrectParameters()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureImageStorage>>();
        var blobContainerClient = Substitute.For<BlobContainerClient>();
        var blobServiceClient = Substitute.For<BlobServiceClient>();
        blobServiceClient.GetBlobContainerClient(Arg.Any<string>()).Returns(blobContainerClient);

        var options = Substitute.For<IOptionsMonitor<AzureStorageOptions>>();
        options.CurrentValue.Returns(new AzureStorageOptions
        {
            Uri = "test-connection-string",
            Container = "test-container"
        });

        var imageStream = new MemoryStream();
        var ct = new CancellationToken();

        var imageStorage = new AzureImageStorage(logger, blobServiceClient, options);

        // Act
        await imageStorage.StoreImageAsync(imageStream, "test-path", ct);

        // Assert
        blobServiceClient.Received(1).GetBlobContainerClient("test-container");
        await blobContainerClient.Received(1).UploadBlobAsync("test-path", imageStream, ct);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task StoreImageAsync_ReturnMatchesUploadResponse(bool uploadResponse)
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureImageStorage>>();

        var rawResponse = Substitute.For<Response>();
        rawResponse.IsError.Returns(!uploadResponse);

        var response = Substitute.For<Response<BlobContentInfo>>();
        response.GetRawResponse().Returns(rawResponse);

        var blobContainerClient = Substitute.For<BlobContainerClient>();
        blobContainerClient.UploadBlobAsync(Arg.Any<string>(), Arg.Any<Stream>(), Arg.Any<CancellationToken>()).Returns(Task.FromResult(response));

        var blobServiceClient = Substitute.For<BlobServiceClient>();
        blobServiceClient.GetBlobContainerClient(Arg.Any<string>()).Returns(blobContainerClient);

        var options = Substitute.For<IOptionsMonitor<AzureStorageOptions>>();
        options.CurrentValue.Returns(new AzureStorageOptions
        {
            Uri = "test-connection-string",
            Container = "test-container"
        });

        var imageStream = new MemoryStream();
        var ct = new CancellationToken();

        var imageStorage = new AzureImageStorage(logger, blobServiceClient, options);

        // Act
        var result = await imageStorage.StoreImageAsync(imageStream, "test-path", ct);

        // Assert
        Assert.Equal(uploadResponse, result);
    }
}

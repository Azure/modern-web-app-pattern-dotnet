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
        var blobClient = Substitute.For<BlobClient>();
        var blobContainerClient = Substitute.For<BlobContainerClient>();
        blobContainerClient.GetBlobClient("test-path").Returns(blobClient);
        var blobServiceClient = Substitute.For<BlobServiceClient>();
        blobServiceClient.GetBlobContainerClient("test-container").Returns(blobContainerClient);

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
        await blobClient.Received(1).UploadAsync(imageStream, true, ct);
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

        var blobClient = Substitute.For<BlobClient>();
        blobClient.UploadAsync(Arg.Any<Stream>(), Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(Task.FromResult(response));

        var blobContainerClient = Substitute.For<BlobContainerClient>();
        blobContainerClient.GetBlobClient("test-path").Returns(blobClient);

        var blobServiceClient = Substitute.For<BlobServiceClient>();
        blobServiceClient.GetBlobContainerClient("test-container").Returns(blobContainerClient);

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

using System.Net;

namespace Relecloud.TicketRenderer.IntegrationTests;

public class TicketRenderingTest(TicketRendererFixture factory)
        : IClassFixture<TicketRendererFixture>
{
    [Fact]
    public async Task Get_HealthChecksFailsWithoutAzureServices()
    {
        // Arrange
        var client = factory.CreateClient();

        // Act
        var response = await client.GetAsync("/health");

        // Assert
        // Note that we could mock the blob storage services to allow this to succeed,
        // but there's no easy way to mock the Azure Service Bus. The health checks
        // library creates its own Service Bus client based on a configured endpoint
        // without using DI. Given that, we just check that we get the expected failure response.
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task MessageReceived_GeneratesImage()
    {
        // Arrange
        var client = factory.CreateClient();

        var request = new TicketRenderRequestEvent(
            Guid.NewGuid(),
            new Ticket
            {
                Id = 0,
                User = new(),
                Customer = new()
                {
                    Email = "customer@example.com"
                },
                Concert = new()
                {
                    Location = "The Releclouds Arena",
                    Artist = "The Releclouds",
                    StartTime = new DateTimeOffset(2024, 04, 02, 19, 0, 0, TimeSpan.Zero),
                    Price = 42
                }
            }, "ticket-path.png",
            new DateTime());

        factory.BlobClient.Uploads.Clear();

        // Act
        await factory.ServiceBusClient.Processor.SimulateMessageAsync(request, CancellationToken.None);
        await Task.Delay(100);

        // Assert
        Assert.Equal(1, factory.ServiceBusClient.Processor.StartProcessingAsyncCallCount);
        var image = Assert.Single(factory.BlobClient.Uploads);
        RelecloudTestHelpers.AssertStreamsEquivalent(RelecloudTestHelpers.GetTestImageStream(), new MemoryStream(image, false), "actual.png");
    }
}

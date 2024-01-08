﻿using System.Net;

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
        var response = await client.GetAsync("/health", CancellationToken.None);

        // Assert
        // Note that we could mock the blob storage services to allow this to succeed,
        // but there's no easy way to mock the Azure Service Bus. The health checks
        // library creates its own Service Bus client based on a configured endpoint
        // without using DI. Given that, we just check that we get the expected failure response.
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [InlineData("ticket-path.png")]
    [InlineData("")]
    [InlineData(null)]
    [Theory]
    public async Task MessageReceived_GeneratesImage(string? outputPath)
    {
        // Arrange
        // Although we don't use the client to send requests, the must be created
        // in order for the message processor to be started.
        factory.CreateClient();

        var expectedPath = string.IsNullOrEmpty(outputPath) ? "ticket-11.png" : outputPath;
        var request = new TicketRenderRequestEvent(
            Guid.NewGuid(),
            new Ticket
            {
                Id = 11,
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
            }, outputPath,
            new DateTime());

        // Reset the state of the blob storage and service bus clients
        factory.BlobClient.Uploads.Clear();
        factory.ServiceBusClient.Sender.SentMessages.Clear();

        // Act
        await factory.ServiceBusClient.Processor.SimulateMessageAsync(request, CancellationToken.None);
        await Task.Delay(100);

        // Assert
        // One image should have been written and it should be correct
        Assert.Equal(1, factory.ServiceBusClient.Processor.StartProcessingAsyncCallCount);
        var image = Assert.Single(factory.BlobClient.Uploads);
        RelecloudTestHelpers.AssertStreamsEquivalent(RelecloudTestHelpers.GetTestImageStream(), new MemoryStream(image, false), "actual.png");

        // One message regarding image render completion should have been queued in the corresponding topic
        var message = Assert.Single(factory.ServiceBusClient.Sender.SentMessages);
        var contents = message.Body.ToObjectFromJson<TicketRenderCompleteEvent>();
        Assert.Equal(request.Ticket.Id, contents.TicketId);
        Assert.Equal(expectedPath, contents.OutputPath);
    }
}

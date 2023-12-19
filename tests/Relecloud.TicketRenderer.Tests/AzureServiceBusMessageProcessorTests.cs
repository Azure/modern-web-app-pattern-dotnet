using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Tests;

public class AzureServiceBusMessageProcessorTests
{
    [Fact]
    public async Task StopAsync_ShouldStopProcessor()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureServiceBusMessageProcessor>>();
        var processor = Substitute.For<ServiceBusProcessor>();
        var ct = new CancellationToken();
        var messageProcessor = new AzureServiceBusMessageProcessor(logger, processor);

        // Act
        await messageProcessor.StopAsync(ct);

        // Assert
        await processor.Received(1).StopProcessingAsync(ct);
    }

    [Fact]
    public async Task DisposeAsync_ShouldDisposeProcessor()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureServiceBusMessageProcessor>>();
        var processor = Substitute.For<ServiceBusProcessor>();
        var messageProcessor = new AzureServiceBusMessageProcessor(logger, processor);

        // Act
        await messageProcessor.DisposeAsync();

        // Assert
        // Can't intercept DisposeAsync() calls, so verify that the processor is closed instead
        // (which should happen as part of disposing it)
        await processor.Received(1).CloseAsync();
    }
}

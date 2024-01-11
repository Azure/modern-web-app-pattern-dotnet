// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Tests;

public class AzureServiceBusMessageSenderTests
{
    [Fact]
    public async Task SendMessageAsync_CallsSenderSendWithCorrectParameters()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureServiceBusMessageSender<TicketRenderCompleteEvent>>>();
        var sender = Substitute.For<ServiceBusSender>();
        var ct = new CancellationToken();
        var message = new TicketRenderCompleteEvent(Guid.NewGuid(), 11, "TicketImagePath", new DateTime());
        var messageSender = new AzureServiceBusMessageSender<TicketRenderCompleteEvent>(logger, sender);

        // Act
        await messageSender.PublishAsync(message, ct);

        // Assert
        await sender.Received(1).SendMessageAsync(Arg.Is<ServiceBusMessage>(m => m.Body.ToObjectFromJson<TicketRenderCompleteEvent>(null).Equals(message)), ct);
    }

    [Fact]
    public async Task CloseAsync_CallsSenderClose()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureServiceBusMessageSender<TicketRenderCompleteEvent>>>();
        var sender = Substitute.For<ServiceBusSender>();
        var ct = new CancellationToken();
        var messageSender = new AzureServiceBusMessageSender<TicketRenderCompleteEvent>(logger, sender);

        // Act
        await messageSender.CloseAsync(ct);

        // Assert
        await sender.Received(1).CloseAsync(ct);
    }

    [Fact]
    public async Task DisposeAsync_CallsSenderDispose()
    {
        // Arrange
        var logger = Substitute.For<ILogger<AzureServiceBusMessageSender<TicketRenderCompleteEvent>>>();
        var sender = Substitute.For<ServiceBusSender>();
        var messageSender = new AzureServiceBusMessageSender<TicketRenderCompleteEvent>(logger, sender);

        // Act
        await messageSender.DisposeAsync();

        // Assert
        await sender.Received(1).DisposeAsync();
    }
}

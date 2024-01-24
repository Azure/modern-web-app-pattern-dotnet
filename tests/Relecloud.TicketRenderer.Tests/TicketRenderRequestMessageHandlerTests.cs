// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.Tests;

public class TicketRenderRequestMessageHandlerTests
{
    [Fact]
    public async Task StartAsync_WhenNoQueueNameIsSpecified_ShouldNotStart()
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = null
        });

        var context = new TestContext(options: options);
        var handler = context.CreateHandler();

        // Act
        await handler.StartAsync(CancellationToken.None);

        // Assert
        // Verify that the message bus was not used to subscribe to any queues or create any message senders
        context.MessageBus.DidNotReceive().CreateMessageSender<TicketRenderCompleteMessage>(Arg.Any<string>());
        await context.MessageBus.DidNotReceive().SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestMessage, CancellationToken, Task>>(), 
            Arg.Any<Func<Exception, CancellationToken, Task>>(), 
            Arg.Any<string>(), 
            Arg.Any<CancellationToken>());
    }

    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("test-response-queue", true)]
    [Theory]
    public async Task StartAsync_SenderCalledOnlyIfResponseQueueSupplied(string? responseQueueName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a response queue name to verify that the sender is instantiated
            RenderCompleteQueueName = responseQueueName
        });

        var ct = new CancellationToken();
        var context = new TestContext(options: options);
        var handler = context.CreateHandler();

        // Act
        await handler.StartAsync(ct);

        // Assert
        // Verify that the message bus was used to subscribe to the queue
        await context.MessageBus.Received(1).SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestMessage, CancellationToken, Task>>(),
            Arg.Any<Func<Exception, CancellationToken, Task>>(),
            "test-queue",
            ct);

        // Verify that the message bus was used to create a message sender if a response queue name was specified
        context.MessageBus.Received(senderUsed ? 1 : 0).CreateMessageSender<TicketRenderCompleteMessage>(responseQueueName!);
    }

    [InlineData(null, false)]
    [InlineData("test-response-queue", true)]
    [Theory]
    public async Task StartAsync_SubscriptionCallbackShouldCallRenderTicket(string? responseQueueName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a response queue name to verify that the sender is instantiated
            RenderCompleteQueueName = responseQueueName
        });

        var context = new TestContext(options: options);
        Func<TicketRenderRequestMessage, CancellationToken, Task>? messageHandler = null;

        context.MessageBus.SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestMessage, CancellationToken, Task>>(), 
            Arg.Any<Func<Exception, CancellationToken, Task>>(), 
            Arg.Any<string>(), 
            Arg.Any<CancellationToken>())
            .Returns(callInfo =>
            {
                // Capture the message handler callback passed to SubscribeAsync so that we can call it
                messageHandler = callInfo.Arg<Func<TicketRenderRequestMessage, CancellationToken, Task>>();
                return context.Processor;
            });

        context.TicketRenderer.RenderTicketAsync(Arg.Any<TicketRenderRequestMessage>(), Arg.Any<CancellationToken>())
            .Returns("outputPath");

        var request = new TicketRenderRequestMessage(Guid.NewGuid(), new Ticket() {  Id = 11 }, "path", new DateTime());
        var ct = new CancellationToken();
        var handler = context.CreateHandler();

        // Act
        await handler.StartAsync(CancellationToken.None);
        messageHandler?.Invoke(request, ct);

        // Assert
        // Verify that the ticket renderer was called with the request and cancellation token
        await context.TicketRenderer.Received(1).RenderTicketAsync(request, ct);
        await context.Sender.Received(senderUsed ? 1 : 0).PublishAsync(Arg.Is<TicketRenderCompleteMessage>(e => e.TicketId == 11 && e.OutputPath.Equals("outputPath")), ct);
    }

    [InlineData(null, false)]
    [InlineData("test-response-queue", true)]
    [Theory]
    public async Task DisposeAsync_DisposesProcessorAndSenderOnce(string? responseQueueName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a response queue name to verify that the sender is instantiated
            RenderCompleteQueueName = responseQueueName
        });

        var context = new TestContext(options: options);
        var handler = context.CreateHandler();

        // Act
        await handler.DisposeAsync();
        await handler.StartAsync(CancellationToken.None);
        await handler.DisposeAsync();
        await handler.DisposeAsync();

        // Assert
        // Verify that the processor and sender were disposed once each
        await context.Processor.Received(1).DisposeAsync();
        await context.Sender.Received(senderUsed ? 1 : 0).DisposeAsync();
    }

    [InlineData(null, false)]
    [InlineData("test-response-queue", true)]
    [Theory]
    public async Task StopAsync_StopsProcessorAndSenderOnce(string? responseQueueName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a response queue name to verify that the sender is instantiated
            RenderCompleteQueueName = responseQueueName
        });

        var ct = new CancellationToken();
        var context = new TestContext(options: options);
        var handler = context.CreateHandler();

        // Act
        await handler.StopAsync(ct);
        await handler.StartAsync(CancellationToken.None);
        await handler.StopAsync(ct);

        // Assert
        // Verify that the processor and sender were both stopped (but only after starting)
        await context.Processor.Received(1).StopAsync(ct);
        await context.Sender.Received(senderUsed ? 1 : 0).CloseAsync(ct);
    }
}

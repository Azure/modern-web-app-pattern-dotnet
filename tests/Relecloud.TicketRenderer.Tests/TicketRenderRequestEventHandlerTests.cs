namespace Relecloud.TicketRenderer.Tests;

public class TicketRenderRequestEventHandlerTests
{
    [Fact]
    public async Task StartAsync_WhenNoQueueNameIsSpecified_ShouldNotStart()
    {
        // Arrange
        var options = Options.Create(new AzureServiceBusOptions
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
        context.MessageBus.DidNotReceive().CreateMessageSender<TicketRenderCompleteEvent>(Arg.Any<string>());
        await context.MessageBus.DidNotReceive().SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestEvent, CancellationToken, Task>>(), 
            Arg.Any<Func<Exception, CancellationToken, Task>>(), 
            Arg.Any<string>(), 
            Arg.Any<CancellationToken>());
    }

    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("test-topic", true)]
    [Theory]
    public async Task StartAsync_SenderCalledOnlyIfTopicSupplied(string? topicName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new AzureServiceBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a topic name to verify that the sender is instantiated
            RenderedTicketTopicName = topicName
        });

        var ct = new CancellationToken();
        var context = new TestContext(options: options);
        var handler = context.CreateHandler();

        // Act
        await handler.StartAsync(ct);

        // Assert
        // Verify that the message bus was used to subscribe to the queue
        await context.MessageBus.Received(1).SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestEvent, CancellationToken, Task>>(),
            Arg.Any<Func<Exception, CancellationToken, Task>>(),
            "test-queue",
            ct);

        // Verify that the message bus was used to create a message sender if a topic name was specified
        context.MessageBus.Received(senderUsed ? 1 : 0).CreateMessageSender<TicketRenderCompleteEvent>(topicName!);
    }

    [InlineData(null, false)]
    [InlineData("test-topic", true)]
    [Theory]
    public async Task StartAsync_SubscriptionCallbackShouldCallRenderTicket(string? topicName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new AzureServiceBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a topic name to verify that the sender is instantiated
            RenderedTicketTopicName = topicName
        });

        var context = new TestContext(options: options);
        Func<TicketRenderRequestEvent, CancellationToken, Task>? messageHandler = null;

        context.MessageBus.SubscribeAsync(
            Arg.Any<Func<TicketRenderRequestEvent, CancellationToken, Task>>(), 
            Arg.Any<Func<Exception, CancellationToken, Task>>(), 
            Arg.Any<string>(), 
            Arg.Any<CancellationToken>())
            .Returns(callInfo =>
            {
                // Capture the message handler callback passed to SubscribeAsync so that we can call it
                messageHandler = callInfo.Arg<Func<TicketRenderRequestEvent, CancellationToken, Task>>();
                return context.Processor;
            });

        context.TicketRenderer.RenderTicketAsync(Arg.Any<TicketRenderRequestEvent>(), Arg.Any<CancellationToken>())
            .Returns("outputPath");

        var request = new TicketRenderRequestEvent(Guid.NewGuid(), new Ticket() {  Id = 11 }, "path", new DateTime());
        var ct = new CancellationToken();
        var handler = context.CreateHandler();

        // Act
        await handler.StartAsync(CancellationToken.None);
        messageHandler?.Invoke(request, ct);

        // Assert
        // Verify that the ticket renderer was called with the request and cancellation token
        await context.TicketRenderer.Received(1).RenderTicketAsync(request, ct);
        await context.Sender.Received(senderUsed ? 1 : 0).PublishAsync(Arg.Is<TicketRenderCompleteEvent>(e => e.TicketId == 11 && e.OutputPath.Equals("outputPath")), ct);
    }

    [InlineData(null, false)]
    [InlineData("test-topic", true)]
    [Theory]
    public async Task DisposeAsync_DisposesProcessorAndSenderOnce(string? topicName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new AzureServiceBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a topic name to verify that the sender is instantiated
            RenderedTicketTopicName = topicName
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
    [InlineData("test-topic", true)]
    [Theory]
    public async Task StopAsync_StopsProcessorAndSenderOnce(string? topicName, bool senderUsed)
    {
        // Arrange
        var options = Options.Create(new AzureServiceBusOptions
        {
            Namespace = "test-namespace",
            RenderRequestQueueName = "test-queue",

            // Use a topic name to verify that the sender is instantiated
            RenderedTicketTopicName = topicName
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
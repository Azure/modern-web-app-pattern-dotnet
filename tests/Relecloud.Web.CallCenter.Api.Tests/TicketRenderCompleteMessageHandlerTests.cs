// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.CallCenter.Api.Tests;

public class TicketRenderCompleteMessageHandlerTests
{

    [InlineData(null)]
    [InlineData("")]
    [InlineData("test-queue")]
    [Theory]
    public async Task StartAsync_ShouldSubscribeToMessageBus_WhenQueueNameIsNotNullOrEmpty(string queueName)
    {
        // Arrange
        var options = Options.Create(new MessageBusOptions { RenderedTicketQueueName = queueName });
        var ct = new CancellationToken();
        var serviceProvider = new ServiceCollection().BuildServiceProvider();
        var logger = Substitute.For<ILogger<TicketRenderCompleteMessageHandler>>();
        var messageBus = Substitute.For<IMessageBus>();

        var handler = new TicketRenderCompleteMessageHandler(serviceProvider, options, messageBus, logger);

        // Act
        await handler.StartAsync(ct);

        // Assert
        if (string.IsNullOrEmpty(queueName))
        {
            await messageBus.DidNotReceive().SubscribeAsync(
                Arg.Any<Func<TicketRenderCompleteMessage, CancellationToken, Task>>(),
                Arg.Any<Func<Exception, CancellationToken, Task>>(),
                Arg.Any<string>(),
                Arg.Any<CancellationToken>());
        }
        else
        {
            await messageBus.Received(1).SubscribeAsync(
                Arg.Any<Func<TicketRenderCompleteMessage, CancellationToken, Task>>(),
                Arg.Any<Func<Exception, CancellationToken, Task>>(),
                queueName,
                ct);
        }
    }

    [InlineData(true)]
    [InlineData(false)]
    [Theory]
    public async Task ProcessTicketRenderCompleteMessage_ShouldUpdateTicketImageName_WhenTicketExists(bool ticketExists)
    {
        // Arrange
        Func<TicketRenderCompleteMessage, CancellationToken, Task>? messageHandler = null;

        var ct = new CancellationToken();
        var options = Options.Create(new MessageBusOptions { RenderedTicketQueueName = "test-queue" });
        var logger = Substitute.For<ILogger<TicketRenderCompleteMessageHandler>>();

        var messageBus = Substitute.For<IMessageBus>();
        await messageBus.SubscribeAsync(
            Arg.Do<Func<TicketRenderCompleteMessage, CancellationToken, Task>>(handler => messageHandler = handler),
            Arg.Any<Func<Exception, CancellationToken, Task>>(),
            "test-queue",
            ct);

        var database = await TestHelpers.CreateTestDatabaseAsync();
        var serviceProvider = new ServiceCollection()
            .AddSingleton(sp => database)
            .BuildServiceProvider();

        var ticketRenderCompleteMessage = new TicketRenderCompleteMessage(Guid.NewGuid(), ticketExists ? 11 : 5, "TestPath", DateTime.Now);

        var handler = new TicketRenderCompleteMessageHandler(serviceProvider, options, messageBus, logger);

        // Act
        await handler.StartAsync(ct);
        messageHandler?.Invoke(ticketRenderCompleteMessage, ct);

        // Assert
        Assert.NotNull(messageHandler);
        var ticketPath = database.Tickets.Find(ticketRenderCompleteMessage.TicketId)?.ImageName;
        Assert.Equal(ticketExists ? "TestPath" : null, ticketPath);
    }

    [Fact]
    public async Task StopAsync_ShouldStopMessageProcessor_WhenProcessorIsNotNull()
    {
        // Arrange
        var serviceProvider = Substitute.For<IServiceProvider>();
        var logger = Substitute.For<ILogger<TicketRenderCompleteMessageHandler>>();
        var options = Options.Create(new MessageBusOptions { RenderedTicketQueueName = "test-queue" });
        var processor = Substitute.For<IMessageProcessor>();
        var messageBus = Substitute.For<IMessageBus>();
        messageBus.SubscribeAsync(
            Arg.Any<Func<TicketRenderCompleteMessage, CancellationToken, Task>>(),
            Arg.Any<Func<Exception, CancellationToken, Task>>(),
            Arg.Any<string>(),
            Arg.Any<CancellationToken>())
        .Returns(Task.FromResult(processor));
        var ct = new CancellationToken();

        var handler = new TicketRenderCompleteMessageHandler(serviceProvider, options, messageBus, logger);

        // Act
        await handler.StartAsync(CancellationToken.None);
        await handler.StopAsync(ct);

        // Assert
        await processor.Received().StopAsync(ct);
    }

    [Fact]
    public async Task DisposeAsync_ShouldDisposeMessageProcessor_WhenProcessorIsNotNull()
    {
        // Arrange
        var serviceProvider = Substitute.For<IServiceProvider>();
        var logger = Substitute.For<ILogger<TicketRenderCompleteMessageHandler>>();
        var options = Options.Create(new MessageBusOptions { RenderedTicketQueueName = "test-queue" });
        var processor = Substitute.For<IMessageProcessor>();
        var messageBus = Substitute.For<IMessageBus>();
        messageBus.SubscribeAsync(
            Arg.Any<Func<TicketRenderCompleteMessage, CancellationToken, Task>>(),
            Arg.Any<Func<Exception, CancellationToken, Task>>(),
            Arg.Any<string>(),
            Arg.Any<CancellationToken>())
        .Returns(Task.FromResult(processor));

        var handler = new TicketRenderCompleteMessageHandler(serviceProvider, options, messageBus, logger);

        // Act
        await handler.StartAsync(CancellationToken.None);
        await handler.DisposeAsync();

        // Assert
        await processor.Received().DisposeAsync();
    }

}

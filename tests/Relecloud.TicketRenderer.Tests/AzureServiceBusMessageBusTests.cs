﻿using Azure.Core.Amqp;
using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Tests;

public class AzureServiceBusMessageBusTests
{
    [Fact]
    public async Task CreateMessageSender_PropagatesPath()
    {
        // Arrange
        var path = "TestPath";
        var serviceBusSender = Substitute.For<ServiceBusSender>();
        var serviceBusClient = Substitute.For<ServiceBusClient>();
        serviceBusClient.CreateSender(path).Returns(serviceBusSender);
        var logger = Substitute.For<ILoggerFactory>();
        var messageBus = new AzureServiceBusMessageBus(logger, serviceBusClient);

        // Act
        var sender = messageBus.CreateMessageSender<string>(path);
        await sender.PublishAsync("TestMessage", CancellationToken.None);

        // Assert
        // Validate that the created message sender ends up calling the service bus sender
        await serviceBusSender.Received(1).SendMessageAsync(Arg.Any<ServiceBusMessage>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SubscribeAsync_PropagatesPath()
    {
        // Arrange
        var path = "TestPath";
        var ct = new CancellationToken();
        var serviceBusProcessor = new TestServiceBusProcessor();
        var serviceBusClient = Substitute.For<ServiceBusClient>();
        serviceBusClient.CreateProcessor(path, Arg.Any<ServiceBusProcessorOptions>()).Returns(serviceBusProcessor);
        var logger = Substitute.For<ILoggerFactory>();
        var messageBus = new AzureServiceBusMessageBus(logger, serviceBusClient);

        // Act
        var processor = await messageBus.SubscribeAsync<string>((_, __) => Task.CompletedTask, null, path, ct);

        // Assert
        // Validate that the created message processor ends up calling the service bus processor
        Assert.Equal(1, serviceBusProcessor.StartProcessingAsyncCallCount);
        Assert.Equal(ct, serviceBusProcessor.StartProcessing_CancellationToken);
    }

    [InlineData(true, true)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(false, false)]
    [Theory]
    public async Task SubscribeAsync_UsesHandlers(bool includeErrorHandler, bool validMessage)
    {
        // Arrange
        var path = "TestPath";
        var messageHandlerCalled = 0;
        var errorHandlerCalled = 0;
        var serviceBusProcessor = new TestServiceBusProcessor();
        var serviceBusReceiver = new TestServiceBusReceiver();
        var serviceBusClient = Substitute.For<ServiceBusClient>();
        serviceBusClient.CreateProcessor(path, Arg.Any<ServiceBusProcessorOptions>()).Returns(serviceBusProcessor);
        var logger = Substitute.For<ILoggerFactory>();
        var messageBus = new AzureServiceBusMessageBus(logger, serviceBusClient);

        var exception = new Exception();
        var message = validMessage ? CreateMessage("TestMessage") : CreateInvalidMessage();
        string? messageReceived = null;
        Exception? exceptionReceived = null;

        // Act
        var processor = await messageBus.SubscribeAsync<string>(
            (message, _) => { messageHandlerCalled++; messageReceived = message; return Task.CompletedTask; },
            includeErrorHandler ? ((exception, __) => { errorHandlerCalled++; exceptionReceived = exception; return Task.CompletedTask; }) : null,
            path,
            CancellationToken.None);

        await serviceBusProcessor.SimulateErrorAsync(new ProcessErrorEventArgs(exception, ServiceBusErrorSource.Receive, "TestNamespace", "TestPath", CancellationToken.None));
        await serviceBusProcessor.SimulateMessageAsync(new ProcessMessageEventArgs(message, serviceBusReceiver, null, CancellationToken.None));

        // Assert
        if (validMessage)
        {
            Assert.Equal(1, messageHandlerCalled);
            Assert.Empty(serviceBusReceiver.DeadLetters);
            Assert.Equal("TestMessage", messageReceived);
        }
        else
        {
            Assert.Equal(0, messageHandlerCalled);
            Assert.Collection(serviceBusReceiver.DeadLetters, m => Assert.Equal(message, m));
            Assert.Null(messageReceived);
        }

        if (includeErrorHandler)
        {
            Assert.Equal(1, errorHandlerCalled);
            Assert.Equal(exception, exceptionReceived);
        }
        else
        {
            Assert.Equal(0, errorHandlerCalled);
            Assert.Null(exceptionReceived);
        }
    }

    public static ServiceBusReceivedMessage CreateMessage<T>(T body)
    {
        var data = BinaryData.FromObjectAsJson(body);
        var amqpMessage = new AmqpAnnotatedMessage(AmqpMessageBody.FromData(new[] { data.ToMemory() }));
        return ServiceBusReceivedMessage.FromAmqpMessage(amqpMessage, new BinaryData(Array.Empty<byte>()));
    }

    public static ServiceBusReceivedMessage CreateInvalidMessage()
    {
        var amqpMessage = new AmqpAnnotatedMessage(AmqpMessageBody.FromData(new[] { new ReadOnlyMemory<byte>([0x00, 0x00, 0xBB, 0xBB]) }));
        return ServiceBusReceivedMessage.FromAmqpMessage(amqpMessage, new BinaryData(Array.Empty<byte>()));
    }
}

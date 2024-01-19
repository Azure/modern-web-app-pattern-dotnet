// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.Tests;

internal class TestContext
{
    public ILogger<TicketRenderRequestMessageHandler> Logger { get; set; }
    public IOptions<MessageBusOptions> ServiceBusOptions { get; set; }
    public IMessageBus MessageBus { get; set; }
    public ITicketRenderer TicketRenderer { get; set; }
    public IMessageProcessor Processor { get; set; }
    public IMessageSender<TicketRenderCompleteMessage> Sender { get; set; }

    public TestContext(
        IOptions<MessageBusOptions>? options = null,
        ILogger<TicketRenderRequestMessageHandler>? logger = null,
        IMessageProcessor? processor = null,
        IMessageSender<TicketRenderCompleteMessage>? sender = null,
        IMessageBus? messageBus = null,
        ITicketRenderer? ticketRenderer = null)
    {
        ServiceBusOptions = options
            ?? Options.Create(new MessageBusOptions
            {
                Namespace = "test-namespace",
                RenderRequestQueueName = "test-queue",
                RenderedTicketQueueName = "test-response-queue"
            });

        Logger = logger
            ?? Substitute.For<ILogger<TicketRenderRequestMessageHandler>>();

        Processor = processor
            ?? Substitute.For<IMessageProcessor>();

        Sender = sender
            ?? Substitute.For<IMessageSender<TicketRenderCompleteMessage>>();

        if (messageBus is not null)
        {
            MessageBus = messageBus;
        }
        else
        {
            MessageBus = Substitute.For<IMessageBus>();
            MessageBus.SubscribeAsync(
                Arg.Any<Func<TicketRenderRequestMessage, CancellationToken, Task>>(),
                Arg.Any<Func<Exception, CancellationToken, Task>>(),
                Arg.Any<string>(),
                Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(Processor));
            MessageBus.CreateMessageSender<TicketRenderCompleteMessage>(Arg.Any<string>())
                .Returns(Sender);
        }

        TicketRenderer = ticketRenderer
            ?? Substitute.For<ITicketRenderer>();
    }

    public TicketRenderRequestMessageHandler CreateHandler()
    {
        return new TicketRenderRequestMessageHandler(Logger, ServiceBusOptions, MessageBus, TicketRenderer);
    }
}

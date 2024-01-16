// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.Tests;

internal class TestContext
{
    public ILogger<TicketRenderRequestEventHandler> Logger { get; set; }
    public IOptions<MessageBusOptions> ServiceBusOptions { get; set; }
    public IMessageBus MessageBus { get; set; }
    public ITicketRenderer TicketRenderer { get; set; }
    public IMessageProcessor Processor { get; set; }
    public IMessageSender<TicketRenderCompleteEvent> Sender { get; set; }

    public TestContext(
        IOptions<MessageBusOptions>? options = null,
        ILogger<TicketRenderRequestEventHandler>? logger = null,
        IMessageProcessor? processor = null,
        IMessageSender<TicketRenderCompleteEvent>? sender = null,
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
            ?? Substitute.For<ILogger<TicketRenderRequestEventHandler>>();

        Processor = processor
            ?? Substitute.For<IMessageProcessor>();

        Sender = sender
            ?? Substitute.For<IMessageSender<TicketRenderCompleteEvent>>();

        if (messageBus is not null)
        {
            MessageBus = messageBus;
        }
        else
        {
            MessageBus = Substitute.For<IMessageBus>();
            MessageBus.SubscribeAsync(
                Arg.Any<Func<TicketRenderRequestEvent, CancellationToken, Task>>(),
                Arg.Any<Func<Exception, CancellationToken, Task>>(),
                Arg.Any<string>(),
                Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(Processor));
            MessageBus.CreateMessageSender<TicketRenderCompleteEvent>(Arg.Any<string>())
                .Returns(Sender);
        }

        TicketRenderer = ticketRenderer
            ?? Substitute.For<ITicketRenderer>();
    }

    public TicketRenderRequestEventHandler CreateHandler()
    {
        return new TicketRenderRequestEventHandler(Logger, ServiceBusOptions, MessageBus, TicketRenderer);
    }
}

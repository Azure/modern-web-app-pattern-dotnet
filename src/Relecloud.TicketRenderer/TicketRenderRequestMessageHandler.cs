// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.Extensions.Options;
using Relecloud.Messaging;
using Relecloud.Messaging.Messages;
using Relecloud.TicketRenderer.Services;

namespace Relecloud.TicketRenderer;

/// <summary>
/// Background service that handles requests to render ticket images.
/// </summary>
internal sealed class TicketRenderRequestMessageHandler(
    ILogger<TicketRenderRequestMessageHandler> logger, 
    IOptions<MessageBusOptions> options,
    IMessageBus messageBus, 
    ITicketRenderer ticketRenderer) : IHostedService, IAsyncDisposable
{
    private IMessageProcessor? processor;
    private IMessageSender<TicketRenderCompleteMessage>? sender;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is starting");

        if (options.Value.RenderRequestQueueName is null)
        {
            logger.LogWarning("No queue name was specified. TicketRenderRequestHandler will not start.");
            return;
        }

        // If a queue/topic name was specified, use it to publish messages when tickets are rendered.
        if (!string.IsNullOrEmpty(options.Value.RenderCompleteQueueName))
        {
            sender = messageBus.CreateMessageSender<TicketRenderCompleteMessage>(options.Value.RenderCompleteQueueName);
        }

        // Initialize the message processor to listen for ticket render requests.
        processor = await messageBus.SubscribeAsync<TicketRenderRequestMessage>(
            async (request, cancellationToken) =>
            {
                // Render the ticket image and get the path it was written to.
                var outputPath = await ticketRenderer.RenderTicketAsync(request, cancellationToken);

                // If a queue/topic name was specified, publish a message indicating that the ticket was rendered.
                if (outputPath is not null && sender is not null)
                {
                    await sender.PublishAsync(new TicketRenderCompleteMessage(Guid.NewGuid(), request.Ticket.Id, outputPath, DateTime.Now), cancellationToken);
                }
            },
            null, // Error handling callback
            options.Value.RenderRequestQueueName, // Queue to subscribe to.
            cancellationToken);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is stopping");

        if (processor is not null)
        {
            await processor.StopAsync(cancellationToken);
        }

        if (sender is not null)
        {
            await sender.CloseAsync(cancellationToken);
        }
    }

    // Cleanup IAsyncDisposable dependencies
    // as per https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync#sealed-alternative-async-dispose-pattern
    public async ValueTask DisposeAsync()
    {
        if (processor is not null)
        {
            await processor.DisposeAsync();
            processor = null;
        }

        if (sender is not null)
        {
            await sender.DisposeAsync();
            sender = null;
        }
    }
}

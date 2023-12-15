using Microsoft.Extensions.Options;
using Relecloud.Models.Events;
using Relecloud.TicketRenderer.Models;
using Relecloud.TicketRenderer.Services;

namespace Relecloud.TicketRenderer;

public sealed class TicketRenderRequestHandler(
    ILogger<TicketRenderRequestHandler> logger, 
    IOptions<AzureServiceBusOptions> options,
    IMessageBus messageBus, 
    ITicketRenderer ticketRenderer) : IHostedService, IAsyncDisposable
{
    private IMessageProcessor? processor;
    private IMessageSender<TicketRenderCompleteEvent>? sender;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is starting");

        if (options.Value.RenderRequestQueueName is null)
        {
            logger.LogWarning("No queue name was specified. TicketRenderRequestHandler will not start.");
            return;
        }

        if (!string.IsNullOrEmpty(options.Value.RenderedTicketTopicName))
        {
            sender = messageBus.CreateMessageSender<TicketRenderCompleteEvent>(options.Value.RenderedTicketTopicName);
        }

        var processor = await messageBus.SubscribeAsync<TicketRenderRequestEvent>(
            async (request, cancellationToken) =>
            {
                var outputPath = await ticketRenderer.RenderTicketAsync(request, cancellationToken);
                if (outputPath is not null && sender is not null)
                {
                    await sender.PublishAsync(new TicketRenderCompleteEvent(Guid.NewGuid(), request.Ticket.Id, outputPath, DateTime.Now), cancellationToken);
                }
            },
            null, 
            options.Value.RenderRequestQueueName, 
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

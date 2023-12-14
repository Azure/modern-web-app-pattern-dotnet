using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Options;
using Relecloud.Models.Events;
using Relecloud.TicketRenderer.Models;
using Relecloud.TicketRenderer.Services;

namespace Relecloud.TicketRenderer;

public sealed class TicketRenderRequestHandler(
    ILogger<TicketRenderRequestHandler> logger, 
    IOptions<AzureServiceBusOptions> options,
    ServiceBusClient serviceBusClient, 
    ITicketRenderer ticketRenderer) : IHostedService, IAsyncDisposable
{
    private ServiceBusProcessor? processor;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is starting");

        processor = serviceBusClient.CreateProcessor(options.Value.QueueName, new ServiceBusProcessorOptions
        {
            // Allow the messages to be auto-completed if processing finishes without failure
            AutoCompleteMessages = true,

            // PeekLock mode provides reliability in that unsettled messages will be redelivered on failure
            ReceiveMode = ServiceBusReceiveMode.PeekLock,

            // Containerized processors can scale at the container level and need not scale via the processor options
            MaxConcurrentCalls = 1,
            PrefetchCount = 0
        });

        processor.ProcessMessageAsync += HandleMessage;
        processor.ProcessErrorAsync += HandleError;

        await processor.StartProcessingAsync(cancellationToken);
    }

    private async Task HandleMessage(ProcessMessageEventArgs args)
    {
        logger.LogInformation("Processing message {MessageId} from Azure Service Bus {ServiceBusNamespace}", args.Message.MessageId, args.FullyQualifiedNamespace);

        // Unhandled exceptions in the handler will be caught by the processor and result in abandoning and dead-lettering the message
        var renderRequest = args.Message.Body.ToObjectFromJson<TicketRenderRequestEvent>()
            ?? throw new InvalidOperationException("Message body is not a valid TicketRenderRequestEvent");

        await ticketRenderer.RenderTicketAsync(renderRequest, args.CancellationToken);
        logger.LogInformation("Successfully processed message {MessageId} from Azure Service Bus {ServiceBusNamespace}", args.Message.MessageId, args.FullyQualifiedNamespace);
    }

    private Task HandleError(ProcessErrorEventArgs args)
    {
        logger.LogError(
            args.Exception, 
            "Error processing message from Azure Service Bus {ServiceBusNamespace} (entity {EntityPath}): {ErrorSource} - {Exception}", 
            args.FullyQualifiedNamespace, 
            args.EntityPath, 
            args.ErrorSource,
            args.Exception);

        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is stopping");

        if (processor is not null)
        {
            await processor.StopProcessingAsync(cancellationToken);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (processor is not null)
        {
            await processor.DisposeAsync();
            processor = null;
        }
    }
}

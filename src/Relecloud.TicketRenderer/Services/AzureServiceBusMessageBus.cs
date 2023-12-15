﻿using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Services;

public class AzureServiceBusMessageBus(ILoggerFactory loggerFactory, ServiceBusClient serviceBusClient) : IMessageBus
{
    readonly ILogger<AzureServiceBusMessageBus> logger = loggerFactory.CreateLogger<AzureServiceBusMessageBus>();

    public IMessageSender<T> CreateMessageSender<T>(string path)
    {
        logger.LogDebug("Creating message sender for {Namespace}/{Path}.", serviceBusClient.FullyQualifiedNamespace, path);
        var sender = serviceBusClient.CreateSender(path);
        return new AzureServiceBusMessageSender<T>(loggerFactory.CreateLogger<AzureServiceBusMessageSender<T>>(), sender);
    }

    public async Task<IMessageProcessor> SubscribeAsync<T>(
        Func<T, CancellationToken, Task> messageHandler, 
        Func<Exception, CancellationToken, Task>? errorHandler, 
        string path, 
        CancellationToken cancellationToken)
    {
        logger.LogDebug("Subscribing to messages from {Namespace}/{Path}.", serviceBusClient.FullyQualifiedNamespace, path);
        
        var processor = serviceBusClient.CreateProcessor(path, new ServiceBusProcessorOptions
        {
            // Allow the messages to be auto-completed if processing finishes without failure
            AutoCompleteMessages = true,

            // PeekLock mode provides reliability in that unsettled messages will be redelivered on failure
            ReceiveMode = ServiceBusReceiveMode.PeekLock,

            // Containerized processors can scale at the container level and need not scale via the processor options
            MaxConcurrentCalls = 1,
            PrefetchCount = 0
        });

        processor.ProcessMessageAsync += async args =>
        {
            logger.LogInformation("Processing message {MessageId} from {ServiceBusNamespace}/{Path}", args.Message.MessageId, args.FullyQualifiedNamespace, args.EntityPath);

            // Unhandled exceptions in the handler will be caught by the processor and result in abandoning and dead-lettering the message
            var message = args.Message.Body.ToObjectFromJson<T>()
                ?? throw new InvalidOperationException($"Message body is not a valid {typeof(T).FullName}");

            await messageHandler(message, args.CancellationToken);
            logger.LogInformation("Successfully processed message {MessageId} from {ServiceBusNamespace}/{Path}", args.Message.MessageId, args.FullyQualifiedNamespace, args.EntityPath);
        };

        processor.ProcessErrorAsync += async args =>
        {
            logger.LogError(
                args.Exception, 
                "Error processing message from {ServiceBusNamespace}/{Path}: {ErrorSource} - {Exception}", 
                args.FullyQualifiedNamespace, 
                args.EntityPath, 
                args.ErrorSource,
                args.Exception);

            if (errorHandler != null)
            {
                await errorHandler(args.Exception, args.CancellationToken);
            }
        };

        await processor.StartProcessingAsync(cancellationToken);

        return new AzureServiceBusMessageProcessor(loggerFactory.CreateLogger<AzureServiceBusMessageProcessor>(), processor);
    }
}

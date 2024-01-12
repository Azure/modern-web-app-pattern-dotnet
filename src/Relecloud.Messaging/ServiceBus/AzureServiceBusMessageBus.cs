// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace Relecloud.Messaging.ServiceBus;

/// <summary>
/// Implements message bus functionality using Azure Service Bus.
/// </summary>
internal class AzureServiceBusMessageBus(ILoggerFactory loggerFactory, ServiceBusClient serviceBusClient) : IMessageBus
{
    // This class uses a logger factory so that it can generate the typed loggers
    // needed by the message senders and processors it creates.
    readonly ILogger<AzureServiceBusMessageBus> logger = loggerFactory.CreateLogger<AzureServiceBusMessageBus>();

    public IMessageSender<T> CreateMessageSender<T>(string path)
    {
        logger.LogDebug("Creating message sender for {Namespace}/{Path}.", serviceBusClient.FullyQualifiedNamespace, path);

        // Create an AzureServiceBusMessageSender for the given queue/topic path that can be used to publish messages
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
        
        // Create a processor for the given queue that will process incoming messages
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

        // Called for each message received by the processor
        processor.ProcessMessageAsync += async args =>
        {
            logger.LogInformation("Processing message {MessageId} from {ServiceBusNamespace}/{Path}", args.Message.MessageId, args.FullyQualifiedNamespace, args.EntityPath);

            // Unhandled exceptions in the handler will be caught by the processor and result in abandoning and dead-lettering the message
            try
            {
                var message = args.Message.Body.ToObjectFromJson<T>();
                await messageHandler(message, args.CancellationToken);
                logger.LogInformation("Successfully processed message {MessageId} from {ServiceBusNamespace}/{Path}", args.Message.MessageId, args.FullyQualifiedNamespace, args.EntityPath);
            }
            catch (JsonException)
            {
                logger.LogError("Invalid message body; could not be deserialized to {Type}", typeof(T));
                await args.DeadLetterMessageAsync(args.Message, $"Invalid message body; could not be deserialized to {typeof(T)}", cancellationToken: args.CancellationToken);
            }
        };

        // Called when an unhandled exception occurs in the processor
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

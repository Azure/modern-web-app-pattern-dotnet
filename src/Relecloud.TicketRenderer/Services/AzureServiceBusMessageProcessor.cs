﻿using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Services;

internal class AzureServiceBusMessageProcessor(ILogger<AzureServiceBusMessageProcessor> logger, ServiceBusProcessor processor) : IMessageProcessor
{
    public async Task StopAsync(CancellationToken cancellationToken)
    {
        logger.LogDebug("Stopping message processor for {Namespace}/{Path}.", processor.FullyQualifiedNamespace, processor.EntityPath);
        await processor.StopProcessingAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await processor.DisposeAsync();
    }
}
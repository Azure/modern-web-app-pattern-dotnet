// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Logging;

namespace Relecloud.Messaging.ServiceBus;

/// <summary>
/// A disposable message processor for Azure Service Bus.
/// </summary>
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

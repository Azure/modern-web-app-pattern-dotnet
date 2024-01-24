// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Logging;

namespace Relecloud.Messaging.ServiceBus;

/// <summary>
/// A message sender for publishing messages to specific Azure Service Bus queues or topics.
/// </summary>
internal sealed class AzureServiceBusMessageSender<T>(ILogger<AzureServiceBusMessageSender<T>> logger, ServiceBusSender sender) : IMessageSender<T>
{
    public async Task PublishAsync(T message, CancellationToken cancellationToken)
    {
        logger.LogDebug("Sending message to {Path}.", sender.EntityPath);

        // Automatically serialize the message body to JSON using System.Text.Json
        var sbMessage = new ServiceBusMessage(new BinaryData(message));
        await sender.SendMessageAsync(sbMessage, cancellationToken);
    }

    public async Task CloseAsync(CancellationToken cancellationToken)
    {
        await sender.CloseAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await sender.DisposeAsync();
    }
}

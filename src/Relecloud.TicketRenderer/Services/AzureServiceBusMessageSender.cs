using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Services;

internal sealed class AzureServiceBusMessageSender<T>(ILogger<AzureServiceBusMessageSender<T>> logger, ServiceBusSender sender) : IMessageSender<T>
{
    public async Task PublishAsync(T message, CancellationToken cancellationToken)
    {
        logger.LogDebug("Sending message to {Path}.", sender.EntityPath);
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
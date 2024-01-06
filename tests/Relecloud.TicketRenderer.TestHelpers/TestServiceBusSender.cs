using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestServiceBusSender : ServiceBusSender
{
    public IList<ServiceBusMessage> SentMessages { get; } = [];

    public override Task SendMessageAsync(ServiceBusMessage message, CancellationToken cancellationToken = default)
    {
        SentMessages.Add(message);
        return Task.CompletedTask;
    }

    public override Task CloseAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
}

using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestServiceBusReceiver : ServiceBusReceiver
{
    public IList<ServiceBusReceivedMessage> DeadLetters { get; } = [];

    public override string FullyQualifiedNamespace => "TestNamespace";

    public override string EntityPath => "TestPath";

    public override Task DeadLetterMessageAsync(ServiceBusReceivedMessage message, string deadLetterReason, string? deadLetterErrorDescription = null, CancellationToken cancellationToken = default)
    {
        DeadLetters.Add(message);
        return Task.CompletedTask;
    }
}

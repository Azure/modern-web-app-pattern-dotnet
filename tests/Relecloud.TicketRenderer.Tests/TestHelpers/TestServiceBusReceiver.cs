using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Tests.TestHelpers;

public class TestServiceBusReceiver : ServiceBusReceiver
{
    public override string FullyQualifiedNamespace => "TestNamespace";

    public override string EntityPath => "TestPath";
}

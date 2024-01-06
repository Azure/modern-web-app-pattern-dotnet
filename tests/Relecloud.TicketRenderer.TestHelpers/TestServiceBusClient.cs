using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestServiceBusClient : ServiceBusClient
{
    public TestServiceBusSender Sender { get; }

    public TestServiceBusReceiver Receiver { get;}

    public TestServiceBusProcessor Processor { get; }

    public TestServiceBusClient()
    {
        Sender = new TestServiceBusSender();
        Receiver = new TestServiceBusReceiver();
        Processor = new TestServiceBusProcessor(Receiver);
    }

    public override string FullyQualifiedNamespace => "TestNamespace";

    public Task SimulateReceivedMessageAsync<T>(T messageBody, CancellationToken ct)
    {
        throw new NotImplementedException();
    }

    public override ServiceBusProcessor CreateProcessor(string queueName, ServiceBusProcessorOptions options)
    {
        return Processor;
    }

    public override ServiceBusSender CreateSender(string queueOrTopicName, ServiceBusSenderOptions options)
    {
        return Sender;
    }

    public override ValueTask DisposeAsync() => ValueTask.CompletedTask;
}

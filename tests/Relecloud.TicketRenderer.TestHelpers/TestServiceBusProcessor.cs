using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestServiceBusProcessor(ServiceBusReceiver defaultReceiver) : ServiceBusProcessor
{
    public int StartProcessingAsyncCallCount { get; private set; }
    public CancellationToken StartProcessing_CancellationToken { get; private set; }

    public override string FullyQualifiedNamespace => "TestNamespace";

    public override string EntityPath => "TestPath";

    public Task SimulateErrorAsync(ProcessErrorEventArgs args) => OnProcessErrorAsync(args);

    public Task SimulateMessageAsync(ProcessMessageEventArgs args) => OnProcessMessageAsync(args);

    public Task SimulateMessageAsync<T>(T messageBody, CancellationToken ct)
    {
        var message = ServiceBusModelFactory.ServiceBusReceivedMessage(BinaryData.FromObjectAsJson(messageBody));
        return SimulateMessageAsync(new ProcessMessageEventArgs(message, defaultReceiver, Guid.NewGuid().ToString(), ct));
    }

    public Task SimulateErrorAsync(Exception exception, CancellationToken ct) =>
        SimulateErrorAsync(new ProcessErrorEventArgs(exception, ServiceBusErrorSource.Receive, FullyQualifiedNamespace, EntityPath, Guid.NewGuid().ToString(), ct));

    public override Task StartProcessingAsync(CancellationToken cancellationToken = default)
    {
        StartProcessingAsyncCallCount++;
        StartProcessing_CancellationToken = cancellationToken;
        return Task.CompletedTask;
    }
}

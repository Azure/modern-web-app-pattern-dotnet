using Azure.Core.Amqp;
using Azure.Messaging.ServiceBus;

namespace Relecloud.TicketRenderer.Tests.TestHelpers;

public class TestServiceBusProcessor : ServiceBusProcessor
{
    public int StartProcessingAsyncCallCount { get; private set; }
    public CancellationToken StartProcessing_CancellationToken { get; private set; }

    public TestServiceBusProcessor()
    {
    }

    public Task SimulateErrorAsync(ProcessErrorEventArgs args) => OnProcessErrorAsync(args);

    public Task SimulateMessageAsync(ProcessMessageEventArgs args) => OnProcessMessageAsync(args);

    public override Task StartProcessingAsync(CancellationToken cancellationToken = default)
    {
        StartProcessingAsyncCallCount++;
        StartProcessing_CancellationToken = cancellationToken;
        return Task.CompletedTask;
    }
}

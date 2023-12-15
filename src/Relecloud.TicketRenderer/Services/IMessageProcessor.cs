namespace Relecloud.TicketRenderer.Services;

public interface IMessageProcessor : IAsyncDisposable
{
    Task StopAsync(CancellationToken cancellationToken);
}
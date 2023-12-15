namespace Relecloud.TicketRenderer.Services;

public interface IMessageSender<T> : IAsyncDisposable
{
    Task PublishAsync(T message, CancellationToken cancellationToken);

    Task CloseAsync(CancellationToken cancellationToken);
}
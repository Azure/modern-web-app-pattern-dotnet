namespace Relecloud.TicketRenderer.Services;

public interface IMessageBus
{
    IMessageSender<T> CreateMessageSender<T>(string path);

    Task<IMessageProcessor> SubscribeAsync<T>(
        Func<T, CancellationToken, Task> messageHandler, 
        Func<Exception, CancellationToken, Task>? errorHandler, 
        string path, 
        CancellationToken cancellationToken);
}

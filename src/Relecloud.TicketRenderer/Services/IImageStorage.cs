namespace Relecloud.TicketRenderer.Services;

public interface IImageStorage
{
    Task<bool> StoreImageAsync(Stream image, string path, CancellationToken cancellation);
}

namespace Relecloud.TicketRenderer.Services;

public interface IImageStorage
{
    Task<bool> StoreImageAsync(MemoryStream image, string path);
}

namespace Relecloud.TicketRenderer.Services;

public class AzureImageStorage(ILogger<AzureImageStorage> logger) : IImageStorage
{
    public Task<bool> StoreImageAsync(MemoryStream image, string path)
    {
        throw new NotImplementedException();
    }
}

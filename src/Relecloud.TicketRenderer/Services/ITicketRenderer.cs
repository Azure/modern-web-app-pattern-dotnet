using Relecloud.Models.Events;

namespace Relecloud.TicketRenderer.Services;

public interface ITicketRenderer
{
    Task<string?> RenderTicketAsync(TicketRenderRequestEvent request, CancellationToken cancellation);
}

using Relecloud.Models.Events;

namespace Relecloud.TicketRenderer.Services;

public interface ITicketRenderer
{
    Task RenderTicketAsync(TicketRenderRequestEvent request, CancellationToken cancellation);
}

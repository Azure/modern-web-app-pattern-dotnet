namespace Relecloud.Models.Events;

public record TicketRenderCompleteEvent(Guid EventId, int TicketId, string PathName, DateTime CreationTime);

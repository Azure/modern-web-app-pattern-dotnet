using Relecloud.Models.ConcertContext;

namespace Relecloud.Models.Events;

public record TicketRenderRequestEvent(Guid EventId, Ticket Ticket, string PathName, DateTime CreationTime);

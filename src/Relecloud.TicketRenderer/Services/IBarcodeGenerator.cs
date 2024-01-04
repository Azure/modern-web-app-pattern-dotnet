using Relecloud.Models.ConcertContext;

namespace Relecloud.TicketRenderer.Services;

public interface IBarcodeGenerator
{
    IEnumerable<int> GenerateBarcode(Ticket ticket);
}

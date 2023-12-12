using Relecloud.Models.Services;

namespace Relecloud.Models.TicketManagement
{
    public class CountAvailableTicketsResult : IServiceProviderResult
    {
        public int CountOfAvailableTickets { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }
}

﻿using Relecloud.Models.TicketManagement.Payment;

namespace Relecloud.Models.TicketManagement
{
    public class PurchaseTicketsRequest
    {
        public string? UserId { get; set; }
        public PaymentDetails? PaymentDetails { get; set; }
        public IDictionary<int, int>? ConcertIdsAndTicketCounts { get; set; }
    }
}
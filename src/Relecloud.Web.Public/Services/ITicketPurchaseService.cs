﻿using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Public.Services
{
    public interface ITicketPurchaseService
    {
        Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request);
    }
}
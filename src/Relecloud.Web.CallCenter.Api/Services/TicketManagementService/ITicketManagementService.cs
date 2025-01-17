﻿// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.TicketManagement;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketManagementService
    {
        Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId);
        Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId);
        Task<ReserveTicketsResult> ReserveTicketsAsync(int concertId, string userId, int numberOfTickets, int customerId);
    }
}

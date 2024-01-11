// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketRenderingService
    {
        public Task CreateTicketImageAsync(int ticketId);
    }
}

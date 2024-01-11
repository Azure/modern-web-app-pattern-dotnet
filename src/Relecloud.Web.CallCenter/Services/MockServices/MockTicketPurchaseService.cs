// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.TicketManagement;

namespace Relecloud.Web.CallCenter.Services.MockServices
{
    public class MockTicketPurchaseService : ITicketPurchaseService
    {
        public Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request)
        {
            return Task.FromResult(new PurchaseTicketsResult
            {
                Status = PurchaseTicketsResultStatus.UnableToProcess
            });
        }
    }
}

// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;

namespace Relecloud.Web.CallCenter.ViewModels
{
    public class TicketViewModel
    {
        public const int DefaultPageSize = 5;

        public int TotalCount { get; set; }
        public int CurrentPage { get; set; }

        public ICollection<Ticket> Tickets { get; set; } = new List<Ticket>();
    }
}

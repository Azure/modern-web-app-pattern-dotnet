// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Models.TicketManagement
{
    public class ReserveTicketsResult
    {
        public ICollection<string> TicketNumbers { get; set; } = new List<string>();

        public ReserveTicketsResultStatus Status { get; set; }

        public string ErrorMessage { get; set; } = string.Empty;
    }
}

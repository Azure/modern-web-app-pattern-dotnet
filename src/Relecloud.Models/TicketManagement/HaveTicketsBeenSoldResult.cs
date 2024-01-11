// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.Services;

namespace Relecloud.Models.TicketManagement
{
    public class HaveTicketsBeenSoldResult : IServiceProviderResult
    {
        public bool HaveTicketsBeenSold { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }
}

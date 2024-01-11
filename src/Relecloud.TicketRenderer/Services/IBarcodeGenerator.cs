// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;

namespace Relecloud.TicketRenderer.Services;

public interface IBarcodeGenerator
{
    IEnumerable<int> GenerateBarcode(Ticket ticket);
}

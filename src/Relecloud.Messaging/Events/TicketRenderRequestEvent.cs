// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;

namespace Relecloud.Messaging.Events;

public record TicketRenderRequestEvent(Guid EventId, Ticket Ticket, string? OutputPath, DateTime CreationTime);

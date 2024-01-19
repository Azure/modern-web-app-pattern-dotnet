// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;

namespace Relecloud.Messaging.Messages;

public record TicketRenderRequestMessage(Guid MessageId, Ticket Ticket, string? OutputPath, DateTime CreationTime);

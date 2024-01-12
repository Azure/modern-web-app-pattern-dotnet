// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Messaging.Events;

public record TicketRenderCompleteEvent(Guid EventId, int TicketId, string OutputPath, DateTime CreationTime);

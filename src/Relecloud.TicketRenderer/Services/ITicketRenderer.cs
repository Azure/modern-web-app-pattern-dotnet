// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Messaging.Messages;

namespace Relecloud.TicketRenderer.Services;

public interface ITicketRenderer
{
    /// <summary>
    /// Renders a ticket and returns the path to the rendered image.
    /// </summary>
    /// <param name="request">A message definition describing the ticket to render.</param>
    /// <returns>The path to the rendered ticket in storage or null if no ticket could be rendered.</returns>
    Task<string?> RenderTicketAsync(TicketRenderRequestMessage request, CancellationToken cancellation);
}

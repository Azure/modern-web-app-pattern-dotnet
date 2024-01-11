// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.Services;

public interface IMessageProcessor : IAsyncDisposable
{
    Task StopAsync(CancellationToken cancellationToken);
}
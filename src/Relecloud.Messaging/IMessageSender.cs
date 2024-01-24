// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Messaging;

public interface IMessageSender<T> : IAsyncDisposable
{
    Task PublishAsync(T message, CancellationToken cancellationToken);

    Task CloseAsync(CancellationToken cancellationToken);
}

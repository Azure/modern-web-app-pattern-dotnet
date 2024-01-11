// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.Services;

public interface IImageStorage
{
    Task<bool> StoreImageAsync(Stream image, string path, CancellationToken cancellation);
}

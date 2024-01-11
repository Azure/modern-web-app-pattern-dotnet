// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestBlobClient : BlobClient
{
    public IList<byte[]> Uploads { get; } = [];

    public override Task<Response<BlobContentInfo>> UploadAsync(Stream content, bool overwrite = false, CancellationToken cancellationToken = default)
    {
        // Store the content as bytes rather than a stream since the stream will be disposed.
        var bytes = new byte[content.Length];
        content.Read(bytes, 0, bytes.Length);
        Uploads.Add(bytes);
        return Task.FromResult(Response.FromValue<BlobContentInfo>(null!, new TestAzureResponse(200)));
    }
}
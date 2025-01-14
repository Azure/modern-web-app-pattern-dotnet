﻿// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;
using Relecloud.TicketRenderer.Models;

namespace Relecloud.TicketRenderer.Services;

/// <summary>
/// Stores images in Azure Blob Storage.
/// </summary>
internal class AzureImageStorage(ILogger<AzureImageStorage> logger, BlobServiceClient blobServiceClient, IOptionsMonitor<AzureStorageOptions> options) : IImageStorage
{
    public async Task<bool> StoreImageAsync(Stream image, string path, CancellationToken cancellationToken)
    {
        var blobClient = blobServiceClient.GetBlobContainerClient(options.CurrentValue.Container).GetBlobClient(path);
        var response = await blobClient.UploadAsync(image, overwrite: true, cancellationToken);

        if (response.GetRawResponse().IsError)
        {
            logger.LogError("Error storing image {BlobName} in Azure Blob Storage: {StatusCode}", path, response.GetRawResponse().Status);
            return false;
        }
        {
            logger.LogInformation("Successfully stored image {BlobName} in Azure Blob Storage", path);
            return true;
        }
    }
}

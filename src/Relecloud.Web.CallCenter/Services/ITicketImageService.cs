// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.CallCenter.Services;

public interface ITicketImageService
{
    Task<Stream> GetTicketImagesAsync(string imageName);
}
// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Web.Api.Services.TicketManagementService;

namespace Relecloud.Web.Api.Services.MockServices
{
    public class MockTicketImageService : ITicketImageService
    {
        public Task<Stream> GetTicketImagesAsync(string imageName)
        {
            return Task.FromResult(Stream.Null);
        }
    }
}
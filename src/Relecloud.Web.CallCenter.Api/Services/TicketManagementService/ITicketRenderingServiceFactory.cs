// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    // Reading a feature flag is an asynchronous operation, so it's not possible
    // to register an ITicketRenderingService provider method directly. Instead,
    // use a factory pattern to create the service asynchronously.

    /// <summary>
    /// Interface for generating <see cref="ITicketRenderingService"/> instances based
    /// on current configuration.
    /// </summary>
    public interface ITicketRenderingServiceFactory
    {
        /// <summary>
        /// Creates a new <see cref="ITicketRenderingService"/> instance.
        /// </summary>
        Task<ITicketRenderingService> CreateAsync();
    }
}

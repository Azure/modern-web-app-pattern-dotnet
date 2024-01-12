// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.


using Microsoft.FeatureManagement;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    /// <summary>
    /// A ticket rendering service factory that creates <see cref="ITicketRenderingService"/>
    /// instances based on feature flags.
    /// </summary>
    public class FeatureDependentTicketRenderingServiceFactory : ITicketRenderingServiceFactory
    {
        private const string FeatureName = "DistributedTicketRendering";

        private readonly IFeatureManager featureManager;
        private readonly IServiceProvider serviceProvider;

        public FeatureDependentTicketRenderingServiceFactory(IFeatureManager featureManager, IServiceProvider serviceProvider)
        {
            this.featureManager = featureManager;
            this.serviceProvider = serviceProvider;
        }

        /// <summary>
        /// Returns an <see cref="ITicketRenderingService"/> instance based on feature flags.
        /// If "DistributedTicketRendering" is enabled, a <see cref="DistributedTicketRenderingService"/>
        /// is created, otherwise a <see cref="LocalTicketRenderingService"/> is created.
        /// </summary>
        /// <returns>A new instance of <see cref="DistributedTicketRenderingService"/>
        /// or <see cref="LocalTicketRenderingService"/> depending on the state of the
        /// DistributedTicketRendering feature flag.</returns>
        public async Task<ITicketRenderingService> CreateAsync() =>
            (await featureManager.IsEnabledAsync(FeatureName))
                ? serviceProvider.GetRequiredService<DistributedTicketRenderingService>()
                : serviceProvider.GetRequiredService<LocalTicketRenderingService>();
    }
}

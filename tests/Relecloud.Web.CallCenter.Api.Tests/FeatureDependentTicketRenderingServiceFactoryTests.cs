// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.FeatureManagement;

namespace Relecloud.Web.CallCenter.Api.Tests;

public class FeatureDependentTicketRenderingServiceFactoryTests
{
    [InlineData(true)]
    [InlineData(false)]
    [Theory]
    public async Task CreateAsync_ReturnsExpectedService(bool distributedTicketRenderingEnabled)
    {
        // Arrange
        var featureManager = Substitute.For<IFeatureManager>();
        featureManager.IsEnabledAsync("DistributedTicketRendering").Returns(distributedTicketRenderingEnabled);

        var serviceCollection = new ServiceCollection();
        var options = Substitute.For<IOptions<MessageBusOptions>>();
        options.Value.Returns(new MessageBusOptions { RenderRequestQueueName = "test-queue" });
        serviceCollection.AddSingleton(new DistributedTicketRenderingService(null!, Substitute.For<IMessageBus>(), options, null!));
        serviceCollection.AddSingleton(new LocalTicketRenderingService(null!, null!, null!));
        var serviceProvider = serviceCollection.BuildServiceProvider();

        var factory = new FeatureDependentTicketRenderingServiceFactory(featureManager, serviceProvider);

        // Act
        var service = await factory.CreateAsync();

        // Assert
        if (distributedTicketRenderingEnabled)
        {
            Assert.IsType<DistributedTicketRenderingService>(service);
        }
        else
        {
            Assert.IsType<LocalTicketRenderingService>(service);
        }
    }
}

// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.CallCenter.Api.Tests;

public class DistributedTicketRenderingServiceTests
{
    [Fact]
    public async Task DistributedTicketRenderingService_NullRenderRequestName_ThrowsArgumentNullException()
    {
        // Arrange
        var database = await TestHelpers.CreateTestDatabaseAsync();
        var messageBus = Substitute.For<IMessageBus>();
        var logger = Substitute.For<ILogger<DistributedTicketRenderingService>>();
        var options = Substitute.For<IOptions<MessageBusOptions>>();
        options.Value.Returns(new MessageBusOptions { RenderRequestQueueName = null });

        // Act
        var exception = Assert.Throws<ArgumentNullException>(() => new DistributedTicketRenderingService(database, messageBus, options, logger));

        // Assert
        Assert.Equal("options.RenderRequestQueueName", exception.ParamName);
    }

    [InlineData(true)]
    [InlineData(false)]
    [Theory]
    public async Task CreateTicketImageAsync_PublishesMessageIfTicketIsValid(bool validTicket)
    {
        // Arrange
        var messageSender = Substitute.For<IMessageSender<TicketRenderRequestMessage>>();
        var messageBus = Substitute.For<IMessageBus>();
        messageBus.CreateMessageSender<TicketRenderRequestMessage>(Arg.Any<string>()).Returns(messageSender);

        var database = await TestHelpers.CreateTestDatabaseAsync();

        var logger = Substitute.For<ILogger<DistributedTicketRenderingService>>();

        var options = Substitute.For<IOptions<MessageBusOptions>>();
        options.Value.Returns(new MessageBusOptions { RenderRequestQueueName = "RenderRequestQueueName" });

        var service = new DistributedTicketRenderingService(database, messageBus, options, logger);

        // Act
        await service.CreateTicketImageAsync(validTicket ? 11 : 5);

        // Assert
        await messageSender.Received(validTicket ? 1 : 0).PublishAsync(Arg.Is<TicketRenderRequestMessage>(e => e.Ticket.Id == 11), Arg.Any<CancellationToken>());
    }
}

// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Relecloud.Messaging;
using Relecloud.Messaging.Events;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;

namespace Relecloud.Web.CallCenter.Api.Services.TicketManagementService
{
    internal sealed class TicketRenderCompleteEventHandler : IHostedService, IAsyncDisposable
    {
        private readonly IServiceProvider serviceProvider;
        private readonly IOptions<MessageBusOptions> options;
        private readonly IMessageBus messageBus;
        private readonly ILogger<TicketRenderCompleteEventHandler> logger;

        private IMessageProcessor? processor;

        public TicketRenderCompleteEventHandler(
            IServiceProvider serviceProvider,
            IOptions<MessageBusOptions> options,
            IMessageBus messageBus,
            ILogger<TicketRenderCompleteEventHandler> logger)
        {
            this.serviceProvider = serviceProvider;
            this.options = options;
            this.messageBus = messageBus;
            this.logger = logger;
        }
        public async Task StartAsync(CancellationToken cancellationToken)
        {
            logger.LogInformation("TicketRenderCompleteEventHandler is starting");

            var queueName = options.Value.RenderedTicketQueueName;

            if (string.IsNullOrEmpty(queueName))
            {
                logger.LogWarning("No queue name was specified. TicketRenderCompleteEventHandler will not start.");
                return;
            }

            // Initialize the message processor to listen for ticket render complete events.
            processor = await messageBus.SubscribeAsync<TicketRenderCompleteEvent>(
                ProcessTicketRenderCompleteEvent,
                null, // Error handling callback
                queueName,
                cancellationToken);
        }

        private async Task ProcessTicketRenderCompleteEvent(TicketRenderCompleteEvent ticketRenderCompleteEvent, CancellationToken cancellationToken)
        {
            using (var diScope = serviceProvider.CreateScope())
            {
                // Hosted services are registered as singletons, but it's a best practice
                // to limit DbContext services to scoped lifetime. Therefore, we create a scope
                // and resolve the DbContext from it, on demand, when we need it.
                var database = diScope.ServiceProvider.GetRequiredService<ConcertDataContext>();

                var ticket = database.Tickets
                    .Include(ticket => ticket.Concert)
                    .Include(ticket => ticket.User)
                    .Include(ticket => ticket.Customer)
                    .Where(ticket => ticket.Id == ticketRenderCompleteEvent.TicketId)
                .FirstOrDefault();

                if (ticket is null)
                {
                    logger.LogWarning("No Ticket found for id:{TicketId}", ticketRenderCompleteEvent.TicketId);
                    return;
                }

                // Set the ticket's image name to the path returned by the render event
                // and update the database.
                ticket.ImageName = ticketRenderCompleteEvent.OutputPath;
                database.Update(ticket);
                await database.SaveChangesAsync(cancellationToken);
                logger.LogInformation("Updated ticket image name for id {TicketId}", ticket.Id);
            }
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            logger.LogDebug("TicketRenderCompleteEventHandler is stopping");

            if (processor is not null)
            {
                await processor.StopAsync(cancellationToken);
            }
        }

        // Cleanup IAsyncDisposable dependencies
        // as per https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync#sealed-alternative-async-dispose-pattern
        public async ValueTask DisposeAsync()
        {
            if (processor is not null)
            {
                await processor.DisposeAsync();
                processor = null;
            }
        }
    }
}

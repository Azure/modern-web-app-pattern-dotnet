// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Relecloud.Messaging;
using Relecloud.Messaging.Messages;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    /// <summary>
    /// Ticket rendering service that works by requesting rendering
    /// by a remote service via a message bus.
    /// </summary>
    public class DistributedTicketRenderingService : ITicketRenderingService
    {
        private readonly ConcertDataContext database;
        private readonly ILogger<DistributedTicketRenderingService> logger;
        private readonly IMessageSender<TicketRenderRequestMessage> messageSender;

        public DistributedTicketRenderingService(ConcertDataContext database, IMessageBus messageBus, IOptions<MessageBusOptions> options, ILogger<DistributedTicketRenderingService> logger)
        {
            var queueName = options.Value.RenderRequestQueueName ?? throw new ArgumentNullException("options.RenderRequestQueueName", "No render request queue name specified.");

            this.database = database;
            this.logger = logger;
            messageSender = messageBus.CreateMessageSender<TicketRenderRequestMessage>(queueName);
        }

        public async Task CreateTicketImageAsync(int ticketId)
        {
            // Get the ticket to render an image for.
            var ticket = database.Tickets
                .Include(ticket => ticket.Concert)
                .Include(ticket => ticket.User)
                .Include(ticket => ticket.Customer)
                .Where(ticket => ticket.Id == ticketId)
                .FirstOrDefault();

            if (ticket is null)
            {
                logger.LogWarning("No Ticket found for id:{TicketId}", ticketId);
                return;
            }

            // Publish a message to request that the ticket be rendered.
            // If no output path is specified, the remote ticket rendering service will generate one.
            await messageSender.PublishAsync(new TicketRenderRequestMessage(Guid.NewGuid(), ticket, null, DateTime.Now), CancellationToken.None);
            logger.LogInformation("Requested ticket rendering for ticket {TicketId}.", ticketId);

            // The database is not updated with the blob name until the ticket is rendered.
        }
    }
}

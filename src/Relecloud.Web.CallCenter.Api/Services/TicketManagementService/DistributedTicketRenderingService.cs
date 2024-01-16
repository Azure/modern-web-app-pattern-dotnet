// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Relecloud.Messaging;
using Relecloud.Messaging.Events;
using Relecloud.Models.ConcertContext;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    /// <summary>
    /// Ticket rendering service that works by requesting rendering
    /// by a remote service via a message bus.
    /// </summary>
    public class DistributedTicketRenderingService : ITicketRenderingService
    {
        private const string BlobNameFormatString = "ticket-{0}.png";

        private readonly ConcertDataContext database;
        private readonly ILogger<DistributedTicketRenderingService> logger;
        private readonly IMessageSender<TicketRenderRequestEvent> messageSender;

        public DistributedTicketRenderingService(ConcertDataContext database, IMessageBus messageBus, IOptions<MessageBusOptions> options, ILogger<DistributedTicketRenderingService> logger)
        {
            var queueName = options.Value.RenderRequestQueueName ?? throw new ArgumentNullException("options.RenderRequestQueueName", "No render request queue name specified.");

            this.database = database;
            this.logger = logger;
            messageSender = messageBus.CreateMessageSender<TicketRenderRequestEvent>(queueName);
        }

        public async Task CreateTicketImageAsync(int ticketId)
        {
            var ticket = database.Tickets
                .Include(ticket => ticket.Concert)
                .Include(ticket => ticket.User)
                .Include(ticket => ticket.Customer)
                .Where(ticket => ticket.Id == ticketId)
                .FirstOrDefault();

            if (ticket is null)
            {
                logger.LogWarning($"No Ticket found for id:{ticketId}");
                return;
            }

            // Publish a message to request that the ticket be rendered using a pre-determined blob name.
            var outputPath = string.Format(BlobNameFormatString, ticket.Id);
            await messageSender.PublishAsync(new TicketRenderRequestEvent(Guid.NewGuid(), ticket, outputPath, DateTime.Now), CancellationToken.None);

            // Update the ticket with the blob name.
            await UpdateTicketWithBlobNameAsync(ticket, outputPath);
        }

        private async Task UpdateTicketWithBlobNameAsync(Ticket ticket, string blobName)
        {
            ticket.ImageName = blobName;
            database.Update(ticket);
            await database.SaveChangesAsync();
        }
    }
}

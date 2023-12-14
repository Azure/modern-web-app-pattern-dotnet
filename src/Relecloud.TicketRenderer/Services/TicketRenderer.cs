using Relecloud.Models.Events;
using System.Drawing.Imaging;
using System.Drawing;
using System.Drawing.Drawing2D;

namespace Relecloud.TicketRenderer.Services
{
    public class TicketRenderer(ILogger<TicketRenderer> logger, IImageStorage imageStorage) : ITicketRenderer
    {
        public async Task RenderTicketAsync(TicketRenderRequestEvent request, CancellationToken cancellationToken)
        {
            logger.LogInformation("Rendering ticket {ticket} for event {event}", request.Ticket?.Id.ToString() ?? "<null>", request.EventId);
            var ticketImageBlob = new MemoryStream();

            if (request.Ticket == null)
            {
                logger.LogWarning("Nothing to render for null ticket");
                return;
            }
            if (request.Ticket.Concert == null)
            {
                logger.LogWarning("Cannot find the concert related to this ticket");
                return;
            }
            if (request.Ticket.User == null)
            {
                logger.LogWarning("Cannot find the user related to this ticket");
                return;
            }
            if (request.Ticket.Customer == null)
            {
                logger.LogWarning("Cannot find the customer related to this ticket");
                return;
            }

            // TODO - Replace with Linux friendly alternative
            // https://learn.microsoft.com/en-us/dotnet/core/compatibility/core-libraries/6.0/system-drawing-common-windows-only#recommended-action
            using (var headerFont = new Font("Arial", 18, FontStyle.Bold))
            using (var textFont = new Font("Arial", 12, FontStyle.Regular))
            using (var bitmap = new Bitmap(640, 200, PixelFormat.Format24bppRgb))
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.SmoothingMode = SmoothingMode.AntiAlias;
                graphics.Clear(Color.White);

                // Print concert details.
                graphics.DrawString(request.Ticket.Concert.Artist, headerFont, Brushes.DarkSlateBlue, new PointF(10, 10));
                graphics.DrawString($"{request.Ticket.Concert.Location}   |   {request.Ticket.Concert.StartTime.UtcDateTime}", textFont, Brushes.Gray, new PointF(10, 40));
                graphics.DrawString($"{request.Ticket.Customer.Email}   |   {request.Ticket.Concert.Price.ToString("c")}", textFont, Brushes.Gray, new PointF(10, 60));

                // Print a fake barcode.
                var random = new Random();
                var offset = 15;
                while (offset < 620)
                {
                    var width = 2 * random.Next(1, 3);
                    graphics.FillRectangle(Brushes.Black, offset, 90, width, 90);
                    offset += width + (2 * random.Next(1, 3));
                }

                bitmap.Save(ticketImageBlob, ImageFormat.Png);
                ticketImageBlob.Position = 0;
            }

            await imageStorage.StoreImageAsync(ticketImageBlob, request.PathName, cancellationToken);
        }
    }
}

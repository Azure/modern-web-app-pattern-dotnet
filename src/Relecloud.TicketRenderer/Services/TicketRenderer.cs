﻿using Relecloud.Models.Events;
using SkiaSharp;

namespace Relecloud.TicketRenderer.Services
{
    public class TicketRenderer(ILogger<TicketRenderer> logger, IImageStorage imageStorage) : ITicketRenderer
    {
        private const string TicketNameFormatString = "ticket-{0}.png";

        public async Task<string?> RenderTicketAsync(TicketRenderRequestEvent request, CancellationToken cancellationToken)
        {
            logger.LogInformation("Rendering ticket {ticket} for event {event}", request.Ticket?.Id.ToString() ?? "<null>", request.EventId);

            if (request.Ticket == null)
            {
                logger.LogWarning("Nothing to render for null ticket");
                return null;
            }
            if (request.Ticket.Concert == null)
            {
                logger.LogWarning("Cannot find the concert related to this ticket");
                return null;
            }
            if (request.Ticket.User == null)
            {
                logger.LogWarning("Cannot find the user related to this ticket");
                return null;
            }
            if (request.Ticket.Customer == null)
            {
                logger.LogWarning("Cannot find the customer related to this ticket");
                return null;
            }

            using var headerFont = new SKFont(SKTypeface.FromFamilyName("Arial", SKFontStyle.Bold), 18);
            using var textFont = new SKFont(SKTypeface.FromFamilyName("Arial"), 12);
            using var bluePaint = new SKPaint { Color = SKColors.DarkSlateBlue, Style = SKPaintStyle.StrokeAndFill, IsAntialias = true };
            using var grayPaint = new SKPaint { Color = SKColors.Gray, Style = SKPaintStyle.StrokeAndFill, IsAntialias = true };
            using var blackPaint = new SKPaint { Color = SKColors.Black, Style = SKPaintStyle.StrokeAndFill, IsAntialias = true };
            using var surface = SKSurface.Create(new SKImageInfo(640, 200, SKColorType.Rgb888x)); 
            
            var canvas = surface.Canvas;
            canvas.Clear(SKColors.White);

            // Print concert details.
            canvas.DrawText(SKTextBlob.Create(request.Ticket.Concert.Artist, headerFont), 10, 30, bluePaint);
            canvas.DrawText(SKTextBlob.Create($"{request.Ticket.Concert.Location}   |   {request.Ticket.Concert.StartTime.UtcDateTime}", textFont), 10, 50, grayPaint);
            canvas.DrawText(SKTextBlob.Create($"{request.Ticket.Customer.Email}   |   {request.Ticket.Concert.Price:c}", textFont), 10, 70, grayPaint);

            // Print a fake barcode.
            var random = new Random();
            var offset = 15;
            while (offset < 620)
            {
                var width = 2 * random.Next(1, 3);
                canvas.DrawRect(offset, 95, width, 90, blackPaint);
                offset += width + (2 * random.Next(1, 3));
            }

            using var image = surface.Snapshot();
            using var data = image.Encode(SKEncodedImageFormat.Png, 100);
            
            var outputPath = string.IsNullOrEmpty(request.PathName)
                ? string.Format(TicketNameFormatString, request.Ticket.Id)
                : request.PathName;

            if (await imageStorage.StoreImageAsync(data.AsStream(), outputPath, cancellationToken))
            {
                return outputPath;
            }
            else
            {
                logger.LogError("Failed to store image for ticket {TicketId}", request.Ticket.Id);
                return null;
            }
        }
    }
}

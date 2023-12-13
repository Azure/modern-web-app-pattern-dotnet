namespace Relecloud.TicketRenderer;

public class TicketRenderRequestHandler(ILogger<TicketRenderRequestHandler> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogDebug("TicketRenderRequestHandler is starting");
        stoppingToken.Register(() => logger.LogDebug("TicketRenderRequestHandler is stopping"));

        while (!stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Worker running at: {time}", DateTimeOffset.Now);
            await Task.Delay(1000, stoppingToken);
        }
    }
}

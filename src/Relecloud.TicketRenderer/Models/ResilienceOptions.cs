namespace Relecloud.TicketRenderer.Models;

public class ResilienceOptions
{
    public int MaxRetries { get; set; } = 5;
    public double BaseDelaySecondsBetweenRetries { get; set; } = 0.8;
    public double MaxDelaySeconds { get; set; } = 60;
    public double MaxNetworkTimeoutSeconds { get; set; } = 100;
}

namespace Relecloud.TicketRenderer.Models;

/// <summary>
/// Options for retry policies. This is shared between
/// HTTP (storage) requests and Service Bus requests.
/// If there were a need for different retry behaviors,
/// they could be handled separately.
/// </summary>
internal class ResilienceOptions
{
    public int MaxRetries { get; set; } = 5;
    public double BaseDelaySecondsBetweenRetries { get; set; } = 0.8;
    public double MaxDelaySeconds { get; set; } = 60;
    public double MaxNetworkTimeoutSeconds { get; set; } = 90;
}

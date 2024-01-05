namespace Relecloud.TicketRenderer.Tests;

public class ResilienceOptionsTests
{
    [Fact]
    public void ValidateDefaults()
    {
        var options = new ResilienceOptions();

        Assert.Equal(5, options.MaxRetries);
        Assert.Equal(0.8, options.BaseDelaySecondsBetweenRetries);
        Assert.Equal(60, options.MaxDelaySeconds);
        Assert.Equal(90, options.MaxNetworkTimeoutSeconds);
    }
}

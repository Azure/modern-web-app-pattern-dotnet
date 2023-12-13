namespace Relecloud.TicketRenderer;

public static class Helpers
{
    public static string GetConfigurationValue(IConfiguration configuration, string key)
    {
        var value = configuration[key];
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Could not find configuration value for {key}");
        }
        return value;
    }
}

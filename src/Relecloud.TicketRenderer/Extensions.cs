namespace Relecloud.TicketRenderer;

public static class Extensions
{
    public static string GetConfigurationValue(this IConfiguration configuration, string key)
    {
        var value = configuration[key];
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Could not find configuration value for {key}");
        }
        return value;
    }
}

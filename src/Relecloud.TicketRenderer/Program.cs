using Azure.Core;
using Azure.Identity;
using Relecloud.TicketRenderer;
using Relecloud.TicketRenderer.Models;

var builder = WebApplication.CreateBuilder(args);

// DefaultAzureCredential will work for all cases, but it's nice-to-have to be able to
// specify more specific credentials so that all the options don't need to be iterated.
TokenCredential azureCredentials = builder.Configuration["App:AzureCredentialType"] switch
{
    "VisualStudio" => new VisualStudioCredential(),
    "AzureCLI" => new AzureCliCredential(),
    "ManagedIdentity" => new ManagedIdentityCredential(),
    _ => new DefaultAzureCredential()
};

builder.AddAzureAppConfiguration(azureCredentials);
builder.AddAzureServices(azureCredentials);
builder.AddTicketRenderingServices();

builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["App:Api:ApplicationInsights:ConnectionString"];
});

// Add health checks, including health checks for Azure services that are used by this service.
builder.Services.AddHealthChecks()
    .AddAzureBlobStorage(options =>
    {
        // AddAzureBlobStorage will use the BlobServiceClient registered in DI
        // We just need to specify the container name
        options.ContainerName = builder.Configuration.GetConfigurationValue("App:StorageAccount:Container");
    })
    .AddAzureServiceBusQueue(
        builder.Configuration.GetConfigurationValue("App:ServiceBus:Namespace"),
        builder.Configuration.GetConfigurationValue("App:ServiceBus:RenderRequestQueueName"),
        azureCredentials);

builder.Services.ConfigureHttpClientDefaults(httpConfiguration =>
{
    var resilienceOptions = builder.Configuration.GetSection("App:Resilience").Get<ResilienceOptions>()
        ?? new ResilienceOptions();

    // AddStandardResilienceHandler will apply standard rate limiting, retry, and circuit breaker
    // policies to HTTP requests. The policies can be configured via the options parameter.
    httpConfiguration.AddStandardResilienceHandler(options =>
    {
        options.Retry.MaxRetryAttempts = resilienceOptions.MaxRetries;
        options.Retry.Delay = TimeSpan.FromSeconds(resilienceOptions.BaseDelaySecondsBetweenRetries);
        options.Retry.MaxDelay = TimeSpan.FromSeconds(resilienceOptions.MaxDelaySeconds);
    });
});

var app = builder.Build();

// Although this service receives requests via message bus,
// it has endpoints for health checks.
app.MapHealthChecks("/health");

await app.RunAsync();
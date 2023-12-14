using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Azure;
using Relecloud.TicketRenderer;
using Relecloud.TicketRenderer.Models;
using Relecloud.TicketRenderer.Services;

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

var appConfigUri = builder.Configuration["App:AppConfig:Uri"];
if (appConfigUri is not null)
{
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options
            .Connect(new Uri(appConfigUri), azureCredentials)
            .ConfigureKeyVault(kv =>
            {
                // Some of the values coming from Azure App Configuration are stored Key Vault, use
                // the managed identity of this host for the authentication.
                kv.SetCredential(azureCredentials);
            });
    });
}

// Prefer user secrets over all other configuration, including app configuration
builder.Configuration.AddUserSecrets<Program>(optional: true);

builder.Services.AddOptions<AzureStorageOptions>()
    .BindConfiguration("App:StorageAccount")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddOptions<AzureServiceBusOptions>()
    .BindConfiguration("App:ServiceBus")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddOptions<ResilienceOptions>()
    .BindConfiguration("App:Resilience")
    .ValidateDataAnnotations()
    .ValidateOnStart();

// TODO - Compare with OpenTelemetry
// https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["App:Api:ApplicationInsights:ConnectionString"];
});

builder.Services.AddHealthChecks()
    .AddAzureBlobStorage(options =>
    {
        // AddAzureBlobStorage will use the BlobServiceClient registered in DI
        // We just need to specify the container name
        options.ContainerName = builder.Configuration.GetConfigurationValue("App:StorageAccount:Container");
    })
    .AddAzureServiceBusQueue(
        builder.Configuration.GetConfigurationValue("App:ServiceBus:Namespace"),
        builder.Configuration.GetConfigurationValue("App:ServiceBus:QueueName"),
        azureCredentials);

// TODO - Move these to extension methods
builder.Services.AddHostedService<TicketRenderRequestHandler>();
builder.Services.AddSingleton<IImageStorage, AzureImageStorage>();
builder.Services.AddSingleton<ITicketRenderer, TicketRenderer>();
builder.Services.ConfigureHttpClientDefaults(httpConfiguration =>
{
    var resilienceOptions = builder.Configuration.GetSection("App:Resilience").Get<ResilienceOptions>()
        ?? new ResilienceOptions();

    // AddStandardResilienceHandler will apply standard rate limiting, retry, and circuit breaker
    // policies to HTTP requests. The policies can be configured via the options parameter.
    httpConfiguration.AddStandardResilienceHandler(configure =>
    {
        configure.Retry.MaxRetryAttempts = resilienceOptions.MaxRetries;
        configure.Retry.Delay = TimeSpan.FromSeconds(resilienceOptions.BaseDelaySecondsBetweenRetries);
        configure.Retry.MaxDelay = TimeSpan.FromSeconds(resilienceOptions.MaxDelaySeconds);
    });
});

builder.Services.AddAzureClients(clientConfiguration =>
{
    clientConfiguration.UseCredential(azureCredentials);

    var storageOptions = builder.Configuration.GetSection("App:StorageAccount").Get<AzureStorageOptions>()
        ?? throw new InvalidOperationException("Storage options (App:StorageAccount) not found");

    if (storageOptions.Uri is null)
    {
        throw new InvalidOperationException("Storage options (App:StorageAccount:Uri) not found");
    }

    var serviceBusOptions = builder.Configuration.GetSection("App:ServiceBus").Get<AzureServiceBusOptions>()
        ?? throw new InvalidOperationException("Service Bus options (App:ServiceBus) not found");

    var resilienceOptions = builder.Configuration.GetSection("App:Resilience").Get<ResilienceOptions>()
        ?? new ResilienceOptions();

    clientConfiguration.AddBlobServiceClient(new Uri(storageOptions.Uri));
    clientConfiguration.AddServiceBusClientWithNamespace(serviceBusOptions.Namespace);

    // ConfigureDefaults set standard retry policies for all Azure clients
    // Clients can also specify their own retry policies, if needed.
    clientConfiguration.ConfigureDefaults(options =>
    {
        options.Retry.Mode = RetryMode.Exponential;
        options.Retry.Delay = TimeSpan.FromSeconds(resilienceOptions.BaseDelaySecondsBetweenRetries);
        options.Retry.MaxRetries = resilienceOptions.MaxRetries;
        options.Retry.MaxDelay = TimeSpan.FromSeconds(resilienceOptions.MaxDelaySeconds);
        options.Retry.NetworkTimeout = TimeSpan.FromSeconds(resilienceOptions.MaxNetworkTimeoutSeconds);

    });
});

var app = builder.Build();

app.MapHealthChecks("/health");

await app.RunAsync();
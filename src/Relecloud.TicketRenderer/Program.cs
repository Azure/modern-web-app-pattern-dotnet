using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Azure;
using Relecloud.TicketRenderer;
using Relecloud.TicketRenderer.Models;
using Relecloud.TicketRenderer.Services;

var builder = WebApplication.CreateBuilder(args);

var appConfigUri = builder.Configuration["App:AppConfig:Uri"];
if (appConfigUri is not null)
{
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options
            .Connect(new Uri(appConfigUri), new DefaultAzureCredential())
            .ConfigureKeyVault(kv =>
            {
                // Some of the values coming from Azure App Configuration are stored Key Vault, use
                // the managed identity of this host for the authentication.
                kv.SetCredential(new DefaultAzureCredential());
            });
    });
}

// Prefer user secrets over all other configuration, including app configuration
builder.Configuration.AddUserSecrets<Program>(optional: true);

// TODO - Compare with OpenTelemetry
// https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["App:Api:ApplicationInsights:ConnectionString"];
});

// TODO - Add Storage and Service Bus health checks here
// https://www.nuget.org/packages/AspNetCore.HealthChecks.AzureServiceBus
// https://www.nuget.org/packages/AspNetCore.HealthChecks.AzureStorage
builder.Services.AddHealthChecks();

// TODO - Move these to extension methods
builder.Services.AddHostedService<TicketRenderRequestHandler>();
builder.Services.AddSingleton<IImageStorage, AzureImageStorage>();
builder.Services.AddSingleton<ITicketRenderer, TicketRenderer>();
builder.Services.ConfigureHttpClientDefaults(configure =>
{
    configure.AddStandardResilienceHandler(resilienceOptions =>
    {
        // Resilience options can be configured here
        // https://github.com/dotnet/extensions/tree/main/src/Libraries/Microsoft.Extensions.Http.Resilience
    });
});

builder.Services.AddOptions<AzureStorageOptions>()
    .BindConfiguration("App:StorageAccount")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddOptions<AzureServiceBusOptions>()
    .BindConfiguration("App:ServiceBus")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddAzureClients(clientConfiguration =>
{
    clientConfiguration.UseCredential(new DefaultAzureCredential());


    var storageOptions = builder.Configuration.GetSection("App:StorageAccount").Get<AzureStorageOptions>()
        ?? throw new InvalidOperationException("Storage options (App:StorageAccount) not found");

    if (storageOptions.Uri is null)
    {
        throw new InvalidOperationException("Storage options (App:StorageAccount:Uri) not found");
    }

    var serviceBusOptions = builder.Configuration.GetSection("App:ServiceBus").Get<AzureServiceBusOptions>()
        ?? throw new InvalidOperationException("Service Bus options (App:ServiceBus) not found");

    clientConfiguration.AddBlobServiceClient(new Uri(storageOptions.Uri));
    clientConfiguration.AddServiceBusClientWithNamespace(serviceBusOptions.Namespace);

    // TODO - Get the retry options from configuration
    clientConfiguration.ConfigureDefaults(options =>
    {
        options.Retry.Mode = RetryMode.Exponential;
        options.Retry.MaxRetries = 5;
        options.Retry.MaxDelay = TimeSpan.FromSeconds(60);
        options.Retry.NetworkTimeout = TimeSpan.FromSeconds(90);

    });
});

var app = builder.Build();

app.MapHealthChecks("/health");

await app.RunAsync();
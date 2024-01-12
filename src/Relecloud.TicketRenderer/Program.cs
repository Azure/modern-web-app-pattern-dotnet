// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Core;
using Azure.Identity;
using Relecloud.TicketRenderer;
using Relecloud.TicketRenderer.Models;

var builder = WebApplication.CreateBuilder(args);

// DefaultAzureCredential will work for all cases, but it's nice-to-have to be able to
// specify more specific credentials so that all the options don't need to be iterated.
// Specifying a specific credential type improves performance by avoiding the need to
// iterate through all the credential types. It also improves startup log readability
// by avoiding the (expected) exceptions thrown by incorrect credential types.
// If the expected credential type is not specified, DefaultAzureCredential will be used
// as a fallback.
TokenCredential azureCredentials = builder.Configuration["App:AzureCredentialType"] switch
{
    "AzureCLI" => new AzureCliCredential(),
    "Environment" => new EnvironmentCredential(),
    "ManagedIdentity" => new ManagedIdentityCredential(builder.Configuration["AZURE_CLIENT_ID"]),
    "VisualStudio" => new VisualStudioCredential(),
    "VisualStudioCode" => new VisualStudioCodeCredential(),
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
// The Blob Storage and Service Bus health checks are provided by AspNetCore.Diagnostics.HealthChecks
// (a popular open source project) rather than by Microsoft. https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks
builder.Services.AddHealthChecks()
    .AddAzureBlobStorage(options =>
    {
        // AddAzureBlobStorage will use the BlobServiceClient registered in DI
        // We just need to specify the container name
        options.ContainerName = builder.Configuration.GetRequiredConfigurationValue("App:StorageAccount:Container");
    })
    .AddAzureServiceBusQueue(
        builder.Configuration.GetRequiredConfigurationValue("App:ServiceBus:Namespace"),
        builder.Configuration.GetRequiredConfigurationValue("App:ServiceBus:RenderRequestQueueName"),
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
        options.Retry.UseJitter = true;
    });
});

var app = builder.Build();

// Although this service receives requests via message bus,
// it has endpoints for health checks.
app.MapHealthChecks("/health");

await app.RunAsync();

// Necessary to make this type available for use with integration test fixtures.
public partial class Program { }

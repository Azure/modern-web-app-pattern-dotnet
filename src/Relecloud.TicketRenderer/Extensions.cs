// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Core;
using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Azure;
using Relecloud.TicketRenderer.Models;
using Relecloud.TicketRenderer.Services;

namespace Relecloud.TicketRenderer;

internal static class Extensions
{
    // Helper method to retrieve a configuration value with validation that the value is not null or empty.
    public static string GetRequiredConfigurationValue(this IConfiguration configuration, string key)
    {
        var value = configuration[key];
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Could not find configuration value for {key}");
        }
        return value;
    }

    public static void AddTicketRenderingServices(this WebApplicationBuilder builder)
    {
        builder.Services.AddHostedService<TicketRenderRequestEventHandler>();
        builder.Services.AddSingleton<IImageStorage, AzureImageStorage>();
        builder.Services.AddSingleton<ITicketRenderer, Services.TicketRenderer>();
        builder.Services.AddSingleton<IMessageBus, AzureServiceBusMessageBus>();
        builder.Services.AddTransient<IBarcodeGenerator>(_ => new RandomBarcodeGenerator(615));
    }

    public static void AddAzureAppConfiguration(this WebApplicationBuilder builder, TokenCredential credential)
    {
        var appConfigUri = builder.Configuration["App:AppConfig:Uri"];
        if (appConfigUri is not null)
        {
            builder.Configuration.AddAzureAppConfiguration(options =>
            {
                options
                    .Connect(new Uri(appConfigUri), credential)
                    .ConfigureKeyVault(kv =>
                    {
                        // Some of the values coming from Azure App Configuration are stored Key Vault, use
                        // the managed identity of this host for the authentication.
                        kv.SetCredential(credential);
                    });
            });

            // Prefer user secrets over all other configuration, including app configuration
            builder.Configuration.AddUserSecrets<Program>(optional: true);
        }
    }

    public static void AddAzureServices(this WebApplicationBuilder builder, TokenCredential credential)
    {
        builder.Services.AddOptions<AzureStorageOptions>()
            .BindConfiguration("App:StorageAccount")
            .ValidateDataAnnotations()
            .ValidateOnStart();

        builder.Services.AddOptions<AzureServiceBusOptions>()
            .BindConfiguration("App:ServiceBus")
            .ValidateDataAnnotations()
            .ValidateOnStart();

        // The AddAzureClients extension method helps add multiple Azure SDK clients
        builder.Services.AddAzureClients(clientConfiguration =>
        {
            clientConfiguration.UseCredential(credential);

            var storageOptions = builder.Configuration.GetRequiredSection("App:StorageAccount").Get<AzureStorageOptions>()
                ?? throw new InvalidOperationException("Storage options (App:StorageAccount) not found");

            if (storageOptions.Uri is null)
            {
                throw new InvalidOperationException("Storage options (App:StorageAccount:Uri) not found");
            }

            var serviceBusOptions = builder.Configuration.GetRequiredSection("App:ServiceBus").Get<AzureServiceBusOptions>()
                ?? throw new InvalidOperationException("Service Bus options (App:ServiceBus) not found");

            var resilienceOptions = builder.Configuration.GetSection("App:Resilience").Get<ResilienceOptions>()
                ?? new ResilienceOptions();

            clientConfiguration.AddBlobServiceClient(new Uri(storageOptions.Uri));
            clientConfiguration.AddServiceBusClientWithNamespace(serviceBusOptions.Namespace)
                .ConfigureOptions(options =>
                {
                    // Default resiliency options (set below) only apply to HTTP-based Azure SDK clients.
                    // Service Bus uses AMQP here and, therefore, needs its own retry options configured.
                    options.RetryOptions.Mode = ServiceBusRetryMode.Exponential;
                    options.RetryOptions.Delay = TimeSpan.FromSeconds(resilienceOptions.BaseDelaySecondsBetweenRetries);
                    options.RetryOptions.MaxRetries = resilienceOptions.MaxRetries;
                    options.RetryOptions.MaxDelay = TimeSpan.FromSeconds(resilienceOptions.MaxDelaySeconds);
                    options.RetryOptions.TryTimeout = TimeSpan.FromSeconds(resilienceOptions.MaxNetworkTimeoutSeconds);
                });

            // ConfigureDefaults sets standard retry policies for all HTTP-based Azure clients.
            // Note that this is not the same as the AddStandardResilienceHandler in ConfigureHttpClientDefaults
            // which applies only to HttpClient instances. Those policies are applied to HTTP clients retrieved
            // from dependency injection but not applied to HTTP clients used by Azure SDK clients.
            clientConfiguration.ConfigureDefaults(options =>
            {
                options.Retry.Mode = RetryMode.Exponential;
                options.Retry.Delay = TimeSpan.FromSeconds(resilienceOptions.BaseDelaySecondsBetweenRetries);
                options.Retry.MaxRetries = resilienceOptions.MaxRetries;
                options.Retry.MaxDelay = TimeSpan.FromSeconds(resilienceOptions.MaxDelaySeconds);
                options.Retry.NetworkTimeout = TimeSpan.FromSeconds(resilienceOptions.MaxNetworkTimeoutSeconds);

            });
        });
    }
}

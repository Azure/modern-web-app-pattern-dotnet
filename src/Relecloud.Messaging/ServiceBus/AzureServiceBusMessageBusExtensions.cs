// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Core;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Relecloud.Messaging.ServiceBus;

public static class AzureServiceBusMessageBusExtensions
{
    public static IServiceCollection AddMessageBusOptions(this IServiceCollection services, string configSectionPath)
    {
        services.AddOptions<MessageBusOptions>()
            .BindConfiguration(configSectionPath)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        return services;
    }

    public static IServiceCollection AddAzureServiceBusMessageBus(this IServiceCollection services, string configSectionPath, TokenCredential? azureCredential)
    {
        services.AddMessageBusOptions(configSectionPath);

        services.AddSingleton<IMessageBus, AzureServiceBusMessageBus>();

        // ServiceBusClient is thread-safe and can be reused for the lifetime of the application.
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<MessageBusOptions>>().Value;
            var clientOptions = new ServiceBusClientOptions
            {
                RetryOptions = new ServiceBusRetryOptions
                {
                    Mode = ServiceBusRetryMode.Exponential,
                    MaxRetries = options.MaxRetries,
                    Delay = TimeSpan.FromSeconds(options.BaseDelaySecondsBetweenRetries),
                    MaxDelay = TimeSpan.FromSeconds(options.MaxDelaySeconds),
                    TryTimeout = TimeSpan.FromSeconds(options.TryTimeoutSeconds)
                }
            };

            return new ServiceBusClient(options.Host, azureCredential ?? new DefaultAzureCredential(), clientOptions);
        });

        return services;
    }
}

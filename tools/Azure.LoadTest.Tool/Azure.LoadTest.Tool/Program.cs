using Azure.LoadTest.Tool.Mappers;
using Azure.LoadTest.Tool.Models.CommandOptions;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Serilog;
using System.CommandLine;
using System.CommandLine.NamingConventionBinder;
using System.CommandLine.Parsing;

namespace Azure.LoadTest.Tool
{
    public class Program
    {
        // Expecting that parameters are passed as AZD environment variables
        public async static Task Main(string[] args)
        {
            var rootCommand = new RootCommand
            {
                new Option<string>(
                    "--environment-name",
                    description: "An AZD environment name"),
                new Option<bool>(
                    "--debug",
                    description: "Provides more verbose logging")
            };

            rootCommand.Handler = CommandHandler.Create<AzureLoadTestToolOptions, CancellationToken>(async (options, token) =>
            {
                var host = Host.CreateDefaultBuilder()
                    .ConfigureServices((context, services) =>
                    {
                        services.AddSingleton(options);
                        services.AddTransient<TestPlanUploadService>();
                        services.AddSingleton<AzdParametersProvider>();
                        services.AddTransient<AzureLoadTestDataPlaneOperator>();
                        services.AddTransient<AzureResourceManagerOperator>();
                        services.AddTransient<UserOutputProvider>();
                        services.AddTransient<AzureResourceApiMapper>();
                        services.AddTransient<AppComponentsMapper>();
                    })
                    .UseSerilog((hostingContext, loggerConfiguration) =>
                    {
                        if (options.Debug)
                        {
                            loggerConfiguration.WriteTo.Console().MinimumLevel.Debug();
                        }
                        else
                        {
                            loggerConfiguration.WriteTo.Console().MinimumLevel.Error();
                        }

                        loggerConfiguration.WriteTo.File("log.txt", rollingInterval: RollingInterval.Day).MinimumLevel.Debug();
                    })
                    .Build();

                var userOutput = host.Services.GetService<UserOutputProvider>() ?? throw new ArgumentNullException("Found Improper configuration: Could not build a logger");
                var logger = host.Services.GetService<ILogger<Program>>() ?? throw new ArgumentNullException(nameof(ILogger<Program>));

                if (string.IsNullOrEmpty(options.EnvironmentName))
                {
                    userOutput.WriteFatalError("Missing required parameter --environment-name which specifies where the AZD configuration is loaded.");

                    return;
                }

                // Resolve the registered service
                // separation of concerns - add the Host
                var myService = host.Services.GetService<TestPlanUploadService>();

                if (myService == null)
                {
                    throw new InvalidOperationException("improperly configured dependency injection could not construct TestPlanUploadService");
                }

                try
                {
                    await myService.CreateTestPlanAsync(token);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Could not handle FATAL error:");
                    userOutput.WriteFatalError(ex.Message);
                }
            });

            await rootCommand.InvokeAsync(args);
        }
    }
}
using Azure.LoadTest.Tool.Models.CommandOptions;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
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
                    description: "An AZD environment name")
            };

            rootCommand.Handler = CommandHandler.Create<ParseResult, AzureLoadTestToolOptions, CancellationToken>(async (result, options, token) =>
            {
                var host = Host.CreateDefaultBuilder()
                    .ConfigureServices((context, services) =>
                    {
                        services.AddSingleton(options);
                        services.AddTransient<TestPlanUploadService>();
                        services.AddTransient<AzureLoadTestDataPlaneOperator>();
                        services.AddTransient<AzureResourceManagerOperator>();
                        services.AddTransient<AzdParametersProvider>().AddOptions<AzureLoadTestToolOptions>();
                    })
                    .Build();

                var logger = host.Services.GetService<ILogger<Program>>() ?? throw new ArgumentNullException("Found Improper configuration: Could not build a logger");

                if (string.IsNullOrEmpty(options.EnvironmentName))
                {
                    logger.LogError("Missing required parameter --environment-name which specifies where the AZD configuration is loaded.");
                    
                    return;
                }

                // Resolve the registered service
                var myService = host.Services.GetService<TestPlanUploadService>();

                if (myService == null)
                {
                    throw new InvalidOperationException("improperly configured dependency injection could not construct TestPlanUploadService");
                }

                try
                {
                    await myService.CreateTestPlanAsync(token);

                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.Write("SUCCESS: ");
                    Console.ResetColor();
                    Console.WriteLine($"Completed Load Test configuration and load test was started.{Environment.NewLine}");
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Could not handle FATAL error:");
                }
            });

            await rootCommand.InvokeAsync(args);
        }
    }
}
using Azure.LoadTest.Tool.Models.CommandOptions;
using Azure.LoadTest.Tool.Operators;
using Azure.LoadTest.Tool.Providers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.CommandLine;
using System.CommandLine.NamingConventionBinder;
using System.CommandLine.Parsing;

namespace Azure.LoadTest.Tool
{
    public class Program
    {
        // Expecting that all parameters are passed as AZD environment variables
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

                // Resolve the registered service
                var myService = host.Services.GetService<TestPlanUploadService>();

                if (myService == null)
                {
                    throw new InvalidOperationException("improperly configured dependency injection could not construct TestPlanUploadService");
                }

                await myService.CreateTestPlanAsync(token);
            });

            await rootCommand.InvokeAsync(args);
        }
    }
}
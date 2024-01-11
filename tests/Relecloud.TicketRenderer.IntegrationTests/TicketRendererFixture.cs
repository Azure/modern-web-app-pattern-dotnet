// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Relecloud.TicketRenderer.IntegrationTests;

public class TicketRendererFixture : WebApplicationFactory<Program>
{
    public TestBlobClient BlobClient { get; } = new();

    public TestServiceBusClient ServiceBusClient { get; } = new();

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.ConfigureHostConfiguration(configuration =>
        {
            // Clear all configuration sources so that the test environment doesn't
            // inherit user secrets or other configuration values from the development
            // environment.
            // This means that the test environment won't have access to real
            // Azure resources, but it also means that the tests will be isolated.
            configuration.Sources.Clear();

            // Add test configuration so that options validation succeeds
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                { "App:StorageAccount:Uri", "http://localhost" },
                { "App:StorageAccount:Container", "test" },
                { "App:ServiceBus:Namespace", "test-namespace" },
                { "App:ServiceBus:RenderRequestQueueName", "test-render-request-queue" },
                { "App:ServiceBus:RenderedTicketTopicName", "test-rendered-ticket-topic" },
            });
        });

        return base.CreateHost(builder);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Replace the Service Bus client with a test implementation
            services.AddSingleton<ServiceBusClient>(ServiceBusClient);

            // Mock the Blob service client to use a test implementation of BlobClient
            var blobContainerClient = Substitute.For<BlobContainerClient>();
            blobContainerClient.GetBlobClient(Arg.Any<string>()).Returns(BlobClient);
            var blobServiceClient = Substitute.For<BlobServiceClient>();
            blobServiceClient.GetBlobContainerClient(Arg.Any<string>()).Returns(blobContainerClient);
            services.AddSingleton(blobServiceClient);

            // Use a test implementation of the barcode generator so that
            // images are consistent
            services.AddSingleton<IBarcodeGenerator>(new TestBarcodeGenerator(615));
        });

        builder.UseEnvironment("Development");
    }
}

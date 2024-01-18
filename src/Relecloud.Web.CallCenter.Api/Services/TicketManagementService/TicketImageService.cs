// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Identity;
using Azure.Storage.Blobs;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketImageService : ITicketImageService
    {
        private readonly ILogger<TicketImageService> logger;
        private readonly BlobContainerClient blobContainerClient;

        public TicketImageService(IConfiguration configuration, ILogger<TicketImageService> logger)
        {
            this.logger = logger;

            // It is best practice to create Azure SDK clients once and reuse them.
            this.blobContainerClient = new BlobServiceClient(new Uri(configuration["App:StorageAccount:Uri"]), new DefaultAzureCredential())
                .GetBlobContainerClient(configuration["App:StorageAccount:Container"]);
        }

        public Task<Stream> GetTicketImagesAsync(string imageName)
        {
            try
            {
                this.logger.LogInformation("Retrieving image {ImageName} from blob storage container {ContainerName}.", imageName, blobContainerClient.Name);
                var blobClient = blobContainerClient.GetBlobClient(imageName);

                return blobClient.OpenReadAsync();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unable to retrieve image {ImageName} from blob storage container {ContainerName}", imageName, blobContainerClient.Name);
                return Task.FromResult(Stream.Null);
            }
        }
    }
}

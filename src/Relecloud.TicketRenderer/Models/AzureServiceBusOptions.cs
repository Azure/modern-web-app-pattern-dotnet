using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Models;

public class AzureServiceBusOptions
{
    [Required]
    public string? Namespace { get; set; }

    [Required]
    public string? QueueName { get; set; }
}

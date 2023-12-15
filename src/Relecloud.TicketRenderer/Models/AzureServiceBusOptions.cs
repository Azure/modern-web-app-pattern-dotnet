using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Models;

internal class AzureServiceBusOptions
{
    [Required]
    public string? Namespace { get; set; }

    [Required]
    public string? RenderRequestQueueName { get; set; }

    // This property is only required if events should be generated
    // when ticket images are produced.
    public string? RenderedTicketTopicName { get; set; }
}

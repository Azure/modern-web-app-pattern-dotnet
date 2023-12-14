using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Models;

public class AzureStorageOptions
{
    [Required]
    public string? Uri { get; set; }

    [Required]
    public string? Container { get; set; }
}

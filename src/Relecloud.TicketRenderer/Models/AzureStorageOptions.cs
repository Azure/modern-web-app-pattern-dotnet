// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Models;

internal class AzureStorageOptions
{
    [Required]
    public string? Uri { get; set; }

    [Required]
    public string? Container { get; set; }
}

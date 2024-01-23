// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using System.ComponentModel.DataAnnotations;

namespace Relecloud.Messaging;

public class MessageBusOptions
{
    [Required]
    public string? Namespace { get; set; }

    [Required]
    public string? RenderRequestQueueName { get; set; }

    // This property is only required if messages should be generated
    // when ticket images are produced.
    public string? RenderCompleteQueueName { get; set; }

    public int MaxRetries { get; set; } = 3;

    public double BaseDelaySecondsBetweenRetries { get; set; } = 0.8;

    public double MaxDelaySeconds { get; set; } = 60;

    public double TryTimeoutSeconds { get; set; } = 60;
}

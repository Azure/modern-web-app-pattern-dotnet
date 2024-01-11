// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.TicketRenderer.Models;
using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Tests;

public class AzureServiceBusOptionsTests
{
    [Fact]
    public void NamespaceIsRequired()
    {
        var options = new AzureServiceBusOptions
        {
            RenderRequestQueueName = "TestQueue",
            RenderedTicketTopicName = "TestTopic"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains("Namespace"));
    }

    [Fact]
    public void RenderRequestQueueNameIsRequired()
    {
        var options = new AzureServiceBusOptions
        {
            Namespace = "TestNamespace",
            RenderedTicketTopicName = "TestTopic"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains("RenderRequestQueueName"));
    }

    [Fact]
    public void RenderedTicketTopicNameIsNotRequired()
    {
        var options = new AzureServiceBusOptions
        {
            Namespace = "TestNamespace",
            RenderRequestQueueName = "TestQueue"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.True(isValid);
        Assert.Null(options.RenderedTicketTopicName);
        Assert.DoesNotContain(results, r => r.MemberNames.Contains("RenderedTicketTopicName"));
    }
}
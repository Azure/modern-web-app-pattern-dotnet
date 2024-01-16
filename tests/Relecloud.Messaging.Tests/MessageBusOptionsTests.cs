// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Tests;

public class MessageBusOptionsTests
{
    [Fact]
    public void NamespaceIsRequired()
    {
        var options = new MessageBusOptions
        {
            RenderRequestQueueName = "TestRequestQueue",
            RenderedTicketQueueName = "TestReponseQueue"
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
        var options = new MessageBusOptions
        {
            Namespace = "TestNamespace",
            RenderedTicketQueueName = "TestReponseQueue"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains("RenderRequestQueueName"));
    }

    [Fact]
    public void RenderedTicketQueueNameIsNotRequired()
    {
        var options = new MessageBusOptions
        {
            Namespace = "TestNamespace",
            RenderRequestQueueName = "TestRequestQueue"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.True(isValid);
        Assert.Null(options.RenderedTicketQueueName);
        Assert.DoesNotContain(results, r => r.MemberNames.Contains("RenderedTicketQueueName"));
    }
}

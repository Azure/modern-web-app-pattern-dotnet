// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.TicketRenderer.Models;
using System.ComponentModel.DataAnnotations;

namespace Relecloud.TicketRenderer.Tests;

public class AzureStorageOptionsTests
{
    [Fact]
    public void UriIsRequired()
    {
        var options = new AzureStorageOptions
        {
            Container = "TestContainer"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains("Uri"));
    }

    [Fact]
    public void ContainerIsRequired()
    {
        var options = new AzureStorageOptions
        {
            Uri = "TestUri"
        };

        var context = new ValidationContext(options);
        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(options, context, results, true);

        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains("Container"));
    }
}
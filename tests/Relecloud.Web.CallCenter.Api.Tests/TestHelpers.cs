// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.EntityFrameworkCore;

namespace Relecloud.Web.CallCenter.Api.Tests;

internal static class TestHelpers
{

    public static async Task<ConcertDataContext> CreateTestDatabaseAsync()
    {
        var contextOptions = new DbContextOptionsBuilder<ConcertDataContext>()
            .UseInMemoryDatabase($"TestDatabase-{Guid.NewGuid()}")
            .Options;
        var database = new ConcertDataContext(contextOptions);

        var concert = new Concert { Id = 1 };
        var customer = new Customer { Id = 1 };
        var user = new User { Id = "0" };

        await database.Tickets.AddRangeAsync(
            new[] {
                new Ticket { Id = 10, Concert = concert, Customer = customer, User = user },
                new Ticket { Id = 11, Concert = concert, Customer = customer, User = user },
                new Ticket { Id = 12, Concert = concert, Customer = customer, User = user },
                new Ticket { Id = 13, Concert = concert, Customer = customer, User = user }
            });
        await database.SaveChangesAsync();

        return database;
    }
}

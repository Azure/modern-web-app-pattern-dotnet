// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;
using System.Diagnostics.CodeAnalysis;

namespace Relecloud.TicketRenderer.Services;

[ExcludeFromCodeCoverage]
public class RandomBarcodeGenerator(int width, int? seed = null) : IBarcodeGenerator
{
    private readonly Random random = seed is null
        ? new Random()
        : new Random(seed.Value);

    public IEnumerable<int> GenerateBarcode(Ticket ticket)
    {
        var currentWidth = 0;
        while (currentWidth < width)
        {
            var nextWidth = random.Next(2, 5);
            currentWidth += nextWidth;
            yield return nextWidth;
        }
    }
}

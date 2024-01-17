// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.TicketRenderer.TestHelpers;

public class TestBarcodeGenerator(int width) : IBarcodeGenerator
{
    public IEnumerable<int> GenerateBarcode(Ticket ticket)
    {
        for (var i = 0; i < width / 3 + 1; i++)
        {
            yield return 3;
        }
    }
}

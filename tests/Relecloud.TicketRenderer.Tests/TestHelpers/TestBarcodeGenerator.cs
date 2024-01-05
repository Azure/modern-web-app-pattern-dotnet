namespace Relecloud.TicketRenderer.Tests.TestHelpers;

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

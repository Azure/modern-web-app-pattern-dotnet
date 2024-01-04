using System.Reflection;
using System.Runtime.InteropServices;
using Renderer = Relecloud.TicketRenderer.Services.TicketRenderer;
namespace Relecloud.TicketRenderer.Tests;

public class TicketRendererTests
{
    [Fact]
    public async Task RenderTicketAsync_ShouldReturnNullWhenTicketIsInvalid()
    {
        // Arrange
        var requests = new[]
        {
            new TicketRenderRequestEvent(Guid.Empty, null!, "TicketImagePath", new DateTime()),
            new TicketRenderRequestEvent(Guid.Empty, new Ticket { User = new User(), Customer = new Customer() }, "TicketImagePath", new DateTime()),
            new TicketRenderRequestEvent(Guid.Empty, new Ticket { User = new User(), Concert = new Concert() }, "TicketImagePath", new DateTime()),
            new TicketRenderRequestEvent(Guid.Empty, new Ticket { Customer = new Customer(), Concert = new Concert() }, "TicketImagePath", new DateTime()),
        };
        var ticketRenderer = new Renderer(Substitute.For<ILogger<Renderer>>(), Substitute.For<IImageStorage>(), Substitute.For<IBarcodeGenerator>());

        // Act
        var results = requests.Select(r => ticketRenderer.RenderTicketAsync(r, CancellationToken.None));

        // Assert
        foreach (var result in results)
        {
            Assert.Null(await result);
        }
    }

    [InlineData("TicketImagePath", true, "TicketImagePath")]
    [InlineData("TicketImagePath", false, null)]
    [InlineData(null, true, "ticket-0.png")]
    [InlineData(null, false, null)]
    [Theory]
    public async Task RenderTicketAsync_ReturnsExpectedPath(string requestPathName, bool storeImageAsyncResult, string expectedReturn)
    {
        // Arrange
        var ticket = new Ticket { Id = 0, User = new User(), Customer = new Customer { Email = "a@test.com" }, Concert = GetConcert() };
        var request = new TicketRenderRequestEvent(Guid.NewGuid(), ticket, requestPathName, new DateTime());
        var barcodeGenerator = Substitute.For<IBarcodeGenerator>();
        var imageStorage = Substitute.For<IImageStorage>();
        imageStorage.StoreImageAsync(Arg.Any<Stream>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns(Task.FromResult(storeImageAsyncResult));
        var ticketRenderer = new Renderer(Substitute.For<ILogger<Renderer>>(), imageStorage, barcodeGenerator);

        // Act
        var result = await ticketRenderer.RenderTicketAsync(request, CancellationToken.None);

        // Assert
        Assert.Equal(expectedReturn, result);
        barcodeGenerator.Received(1).GenerateBarcode(ticket);
    }

    [Fact]
    public async Task RenderTicketAsync_StoreImageWithCorrectData()
    {
        // Arrange
        var expectedImage = GetImageStream();
        var imagesEquivalent = false;
        var request = new TicketRenderRequestEvent(
            Guid.NewGuid(), 
            new Ticket 
            { 
                Id = 0, 
                User = new(), 
                Customer = new() 
                { 
                    Email = "customer@example.com" 
                }, 
                Concert = new()
                {
                    Location = "The Releclouds Arena",
                    Artist = "The Releclouds",
                    StartTime = new DateTimeOffset(2024, 04, 02, 19, 0, 0, TimeSpan.Zero),
                    Price = 42
                }
            }, "ticket-path.png",
            new DateTime());
        var imageStorage = Substitute.For<IImageStorage>();
        imageStorage.StoreImageAsync(Arg.Any<Stream>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns(callInfo =>
        {
            // When StoreImageAsync is called, assert that the image data is correct.
            var actualImage = callInfo.Arg<Stream>();
            imagesEquivalent = AssertEquivalent(expectedImage, actualImage);
            return Task.FromResult(imagesEquivalent);
        });
        var ticketRenderer = new Renderer(Substitute.For<ILogger<Renderer>>(), imageStorage, new TestBarcodeGenerator(615));

        // Act
        var result = await ticketRenderer.RenderTicketAsync(request, CancellationToken.None);

        // Assert
        await imageStorage.Received(1).StoreImageAsync(Arg.Any<Stream>(), request.PathName, CancellationToken.None);
        Assert.Equal(request.PathName, result);
        Assert.True(imagesEquivalent);
    }

    private static bool AssertEquivalent(Stream expected, Stream actual)
    {
        var equivalent = true;

        if (expected.Length != actual.Length)
        {
            equivalent = false;
        }

        if (equivalent)
        {
            var expectedByte = expected.ReadByte();
            var actualByte = actual.ReadByte();
            while (expectedByte != -1 && actualByte != -1)
            {
                if (expectedByte != actualByte)
                {
                    equivalent = false;
                }

                expectedByte = expected.ReadByte();
                actualByte = actual.ReadByte();
            }
        }

        if (!equivalent)
        {
            actual.Position = 0;
            using var actualImage = File.Create("actual.png");
            actual.CopyTo(actualImage);
            actualImage.Flush();
            Assert.Fail("The actual image does not match the expected image. See actual.png.");
        }

        return equivalent;
    }

    private static Stream GetImageStream()
    {
        var resourceName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) 
            ? "Relecloud.TicketRenderer.Tests.ExpectedImages.test-ticket-windows.png" 
            : "Relecloud.TicketRenderer.Tests.ExpectedImages.test-ticket-linux.png";

        return Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Could not find embedded resource: {resourceName}.");
    }

    private static Concert GetConcert() =>
        new()
        {
            Artist = "Test Artist",
            Location = "Test Location",
            StartTime = new DateTime(2024, 1, 1, 12, 0, 0),
            Price = 100
        };
}

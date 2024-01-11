// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using System.Reflection;
using System.Runtime.InteropServices;
using Xunit;

namespace Relecloud.TicketRenderer.TestHelpers;

public class RelecloudTestHelpers
{
    public static Stream GetTestImageStream()
    {
        var resourceName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows)
            ? "Relecloud.TicketRenderer.TestHelpers.ExpectedImages.test-ticket-windows.png"
            : "Relecloud.TicketRenderer.TestHelpers.ExpectedImages.test-ticket-linux.png";

        return Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Could not find embedded resource: {resourceName}.");
    }

    public static bool AssertStreamsEquivalent(Stream expected, Stream actual, string? debugOutFile = null)
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
            if (!string.IsNullOrEmpty(debugOutFile))
            {
                actual.Position = 0;
                using var actualImage = File.Create(debugOutFile);
                actual.CopyTo(actualImage);
                actualImage.Flush();
            }
            Assert.Fail($"The actual stream contents do not match the expected stream.{(string.IsNullOrEmpty(debugOutFile) ? string.Empty : " See " + debugOutFile)})");
        }

        return equivalent;
    }
}

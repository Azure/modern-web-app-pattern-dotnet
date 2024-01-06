using Azure;
using Azure.Core;
using System.Diagnostics.CodeAnalysis;

namespace Relecloud.TicketRenderer.TestHelpers
{
    internal class TestAzureResponse : Response
    {
        private int status;

        public TestAzureResponse(int status)
        {
            this.status = status;
        }

        public override int Status => status;

        public override bool IsError => status >= 400;

        public override string ReasonPhrase => string.Empty;

        public override Stream? ContentStream { get => throw new NotImplementedException(); set => throw new NotImplementedException(); }
        public override string ClientRequestId { get => throw new NotImplementedException(); set => throw new NotImplementedException(); }

        public override void Dispose() { }

        protected override bool ContainsHeader(string name) => false;

        protected override IEnumerable<HttpHeader> EnumerateHeaders() => Enumerable.Empty<HttpHeader>();

        protected override bool TryGetHeader(string name, [NotNullWhen(true)] out string? value)
        {
            value = null;
            return false;
        }

        protected override bool TryGetHeaderValues(string name, [NotNullWhen(true)] out IEnumerable<string>? values)
        {
            values = null;
            return false;
        }
    }
}
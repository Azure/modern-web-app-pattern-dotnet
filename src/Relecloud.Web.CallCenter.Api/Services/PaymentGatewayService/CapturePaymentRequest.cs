// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public class CapturePaymentRequest
    {
        public string HoldCode { get; set; } = string.Empty;
        public double TotalPrice { get; set; }
    }
}

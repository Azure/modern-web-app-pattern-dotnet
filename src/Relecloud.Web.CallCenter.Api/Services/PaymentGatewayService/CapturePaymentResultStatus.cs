// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public enum CapturePaymentResultStatus
    {
        CaptureSuccessful = 0,
        InvalidHoldCode = 1,
        InvalidHoldAmount = 2,
    }
}

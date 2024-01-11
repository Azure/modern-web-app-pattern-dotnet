// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Web.Api.Services.PaymentGatewayService;

namespace Relecloud.Web.Models.Services
{
    public interface IPaymentGatewayService
    {
        Task<PreAuthPaymentResult> PreAuthPaymentAsync(PreAuthPaymentRequest request);
        Task<CapturePaymentResult> CapturePaymentAsync(CapturePaymentRequest request);
    }
}

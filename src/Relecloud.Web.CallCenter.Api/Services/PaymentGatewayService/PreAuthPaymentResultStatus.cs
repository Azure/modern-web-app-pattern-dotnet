// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public enum PreAuthPaymentResultStatus
    {
        FundsOnHold = 0,
        InsufficientFunds = 1,
        NotAValidCard = 3
    }
}

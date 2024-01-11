// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.ConcertContext;
using Relecloud.Models.Services;

namespace Relecloud.Web.Api.Services
{
    public interface IConcertRepository : IConcertContextService
    {
        public void Initialize();
        Task<CreateResult> CreateCustomerAsync(Customer newCustomer);
        Task<Customer?> GetCustomerByEmailAsync(string email);
    }
}

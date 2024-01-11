// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Models.ConcertContext
{
    public class User
    {
        public string Id { get; set; } = new Guid().ToString();
        public string DisplayName { get; set; } = string.Empty;
    }
}
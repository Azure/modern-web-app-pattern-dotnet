// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using System.ComponentModel.DataAnnotations;

namespace Relecloud.Models.ConcertContext
{
    public class Customer
    {
        public int Id { get; set; }

        [MaxLength(75)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(75)]
        public string Email { get; set; } = string.Empty;

        [MaxLength(16)]
        public string Phone { get; set; } = string.Empty;
    }
}

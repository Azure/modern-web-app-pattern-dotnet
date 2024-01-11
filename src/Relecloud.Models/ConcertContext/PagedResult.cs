// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Models.ConcertContext
{
    public class PagedResult<T> where T : new()
    {
        public PagedResult(ICollection<T> pageOfData, int totalCount)
        {
            PageOfData = pageOfData;
            TotalCount = totalCount;
        }

        public int TotalCount { get; set; }
        public ICollection<T> PageOfData { get; set; }
    }
}

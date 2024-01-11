// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Models.ConcertContext
{
    public class DeleteResult : UpdateResult
    {
        public static new DeleteResult SuccessResult()
        {
            return new DeleteResult
            {
                Success = true,
            };
        }
    }
}

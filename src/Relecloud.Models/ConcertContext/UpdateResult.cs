// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

namespace Relecloud.Models.ConcertContext
{
    public class UpdateResult
    {
        public bool Success { get; set; }
        public IDictionary<string, IEnumerable<string>>? ErrorMessages { get; set; }

        public static UpdateResult SuccessResult()
        {
            return new UpdateResult { Success = true };
        }

        public static IDictionary<string, IEnumerable<string>> CreateError(string errorMessage)
        {
            var errors = new Dictionary<string, IEnumerable<string>>();
            errors[string.Empty] = new List<string>
            {
                errorMessage
            };

            return errors;
        }
    }
}

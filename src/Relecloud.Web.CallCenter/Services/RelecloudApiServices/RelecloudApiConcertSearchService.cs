﻿// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Relecloud.Models.Search;
using Relecloud.Models.Services;
using Relecloud.Web.CallCenter.Infrastructure;
using System.Net;
using System.Text.Json;

namespace Relecloud.Web.CallCenter.Services.RelecloudApiServices
{
    public class RelecloudApiConcertSearchService : IConcertSearchService
    {
        private readonly HttpClient httpClient;

        public RelecloudApiConcertSearchService(HttpClient httpClient)
        {
            this.httpClient = httpClient;
        }

        public async Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request)
        {
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Post, "api/Search/Concerts");
            httpRequestMessage.Content = JsonContent.Create(request);
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(SearchAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<SearchResponse<ConcertSearchResult>>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions())
                ?? new SearchResponse<ConcertSearchResult>(request, Array.Empty<ConcertSearchResult>(), Array.Empty<SearchFacet>());
        }

        public async Task<ICollection<string>> SuggestAsync(string query)
        {
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Search/SuggestConcerts?query={query}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(SearchAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<string[]>(responseMessage) ?? Array.Empty<string>();
        }
    }
}

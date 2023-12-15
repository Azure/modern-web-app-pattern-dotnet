using Relecloud.Models.Search;

namespace Relecloud.Models.Services
{
    public interface IConcertSearchService
    {
        Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request);
        Task<ICollection<string>> SuggestAsync(string query);
    }
}

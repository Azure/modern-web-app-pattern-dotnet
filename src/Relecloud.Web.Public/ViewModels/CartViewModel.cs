using Relecloud.Models.ConcertContext;

namespace Relecloud.Web.Public.ViewModels
{
    public class CartViewModel
    {
        public IDictionary<Concert, int> Concerts { get; }
        public int TotalTickets { get; }
        public double TotalPrice { get; }

        public CartViewModel(IDictionary<Concert, int> concerts)
        {
            this.Concerts = concerts;
            this.TotalTickets = this.Concerts.Sum(item => item.Value);
            this.TotalPrice = this.Concerts.Sum(item => item.Key.Price * item.Value);
        }
    }
}
// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.ApplicationInsights;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Models.ConcertContext;
using Relecloud.Models.Services;
using Relecloud.Models.TicketManagement;
using Relecloud.Models.TicketManagement.Payment;
using Relecloud.Web.CallCenter.Infrastructure;
using Relecloud.Web.CallCenter.Services;
using Relecloud.Web.CallCenter.ViewModels;

namespace Relecloud.Web.CallCenter.Controllers
{
    public class CartController : Controller
    {
        #region Fields

        private readonly ITicketPurchaseService ticketPurchaseService;
        private readonly IConcertContextService concertService;
        private readonly TelemetryClient telemetryClient;
        private readonly ILogger<CartController> logger;

        #endregion

        #region Constructors

        public CartController(IConcertContextService concertService, TelemetryClient telemetry, ILogger<CartController> logger, ITicketPurchaseService ticketPurchaseService)
        {
            this.concertService = concertService;
            this.telemetryClient = telemetry;
            this.logger = logger;
            this.ticketPurchaseService = ticketPurchaseService;
        }

        #endregion

        #region Index

        public async Task<IActionResult> Index()
        {
            try
            {
                var model = await GetCartAsync();
                return View(model);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unable to show cart items");
                return View();
            }
        }

        #endregion

        #region Add

        public async Task<IActionResult> Add(int concertId)
        {
            var model = await this.concertService.GetConcertByIdAsync(concertId);
            if (model == null)
            {
                return NotFound();
            }
            return View(model);
        }

        [HttpPost]
        public IActionResult Add(int concertId, int count)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    var cartData = GetCartData();
                    if (!cartData.ContainsKey(concertId))
                    {
                        cartData.Add(concertId, 0);
                    }
                    cartData[concertId] = cartData[concertId] + count;
                    SetCartData(cartData);
                    // Most custom telemetry should go through OpenTelemetry APIs,
                    // but Azure Monitor's OpenTelemetry SDK does not support custom events yet.
                    // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#send-custom-telemetry-using-the-application-insights-classic-api
                    // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#whats-the-current-release-state-of-features-within-the-azure-monitor-opentelemetry-distro
                    this.telemetryClient.TrackEvent("AddToCart", new Dictionary<string, string> {
                        { "ConcertId", concertId.ToString() },
                        { "Count", count.ToString() }
                    });

                    // An alternative which wouldn't require AppInsights SDK usage is to log traces.
                    // Note that these will appear as traces in Application Insights rather than true
                    // separately queryable custom events. But they may work for some scenarios.
                    this.logger.LogInformation("Concert {ConcertId} (count {Count}) added to cart", concertId, count);
                }
                catch (Exception ex)
                {
                    this.logger.LogError(ex, $"Unable to add {concertId} to cart");
                }
            }
            return RedirectToAction(nameof(Index));
        }

        #endregion

        #region Remove

        [HttpPost]
        public IActionResult Remove(int concertId)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    var cartData = GetCartData();
                    if (cartData.ContainsKey(concertId))
                    {
                        cartData.Remove(concertId);
                    }
                    SetCartData(cartData);

                    // Most custom telemetry should go through OpenTelemetry APIs,
                    // but Azure Monitor's OpenTelemetry SDK does not support custom events yet.
                    // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#send-custom-telemetry-using-the-application-insights-classic-api
                    // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#whats-the-current-release-state-of-features-within-the-azure-monitor-opentelemetry-distro
                    this.telemetryClient.TrackEvent("RemoveFromCart", new Dictionary<string, string> { { "ConcertId", concertId.ToString() } });

                    // An alternative which wouldn't require AppInsights SDK usage is to log traces.
                    // Note that these will appear as traces in Application Insights rather than true
                    // separately queryable custom events. But they may work for some scenarios.
                    this.logger.LogInformation("Concert {ConcertId} removed from cart", concertId);                    
                }
                catch (Exception ex)
                {
                    this.logger.LogError(ex, $"Unable to remove {concertId} to cart");
                }
            }

            return RedirectToAction(nameof(Index));
        }

        #endregion

        #region Checkout

        [Authorize]
        public async Task<IActionResult> Checkout()
        {
            var model = await GetCartAsync();
            return View(new CheckoutViewModel
            {
                PaymentDetails = new PaymentDetails(),
                Cart = model
            });
        }

        [Authorize]
        [HttpPost]
        [ActionName(nameof(Checkout))]
        public async Task<IActionResult> CheckoutConfirmed(CheckoutViewModel model)
        {
            try
            {
                if (model == null || model.PaymentDetails is null)
                {
                    ModelState.AddModelError(string.Empty, "Invalid form state data");
                    return View(nameof(Checkout), model);
                }
                if (ModelState.IsValid)
                {
                    var cartData = await GetCartAsync();
                    var serializableDictionary = MapToSerializableDictionary(cartData.Concerts);

                    var purchaseResult = await this.ticketPurchaseService.PurchaseTicketAsync(new PurchaseTicketsRequest
                    {
                        ConcertIdsAndTicketCounts = serializableDictionary,
                        PaymentDetails = model.PaymentDetails,
                        UserId = User.GetUniqueId(),
                    });

                    if (purchaseResult.Status == PurchaseTicketsResultStatus.Success)
                    {
                        // Remove all items from the cart.
                        SetCartData(new Dictionary<int, int>());

                        // Most custom telemetry should go through OpenTelemetry APIs,
                        // but Azure Monitor's OpenTelemetry SDK does not support custom events yet.
                        // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#send-custom-telemetry-using-the-application-insights-classic-api
                        // https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify#whats-the-current-release-state-of-features-within-the-azure-monitor-opentelemetry-distro
                        this.telemetryClient.TrackEvent("CheckoutCart");

                        // An alternative which wouldn't require AppInsights SDK usage is to log traces.
                        // Note that these will appear as traces in Application Insights rather than true
                        // separately queryable custom events. But they may work for some scenarios.
                        this.logger.LogInformation("Cart checked out");

                        return RedirectToAction(nameof(Index), "Ticket");
                    }

                    if (purchaseResult.ErrorMessages is null)
                    {
                        ModelState.AddModelError(string.Empty, "We're sorry but the purchasing service is unavailable at this time.");
                    }
                    else
                    {
                        ModelState.AddErrorMessages(purchaseResult.ErrorMessages);
                    }
                }
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to perform checkout for ${User.Identity!.Name}");
                ModelState.AddModelError(string.Empty, "We're sorry for the iconvenience but there was an error while trying to process your order. Please try again later.");
            }

            model.Cart = await GetCartAsync();
            return View(nameof(Checkout), model);
        }

        private IDictionary<int, int> MapToSerializableDictionary(IDictionary<Concert, int> cartData)
        {
            var result = new Dictionary<int, int>();
            foreach (var key in cartData.Keys)
            {
                result[key.Id] = cartData[key];
            }

            return result;
        }

        #endregion

        #region Helper Methods

        // The key is the concert ID, the value is the number of items in the cart.
        private IDictionary<int, int> GetCartData()
        {
            return this.HttpContext.Session.Get<IDictionary<int, int>>(nameof(CartViewModel)) ?? new Dictionary<int, int>();
        }

        private void SetCartData(IDictionary<int, int> data)
        {
            // Remove keys that have don't have items in the cart anymore.
            foreach (var emptyItemKey in data.Where(item => item.Value <= 0).Select(item => item.Key).ToArray())
            {
                data.Remove(emptyItemKey);
            }
            this.HttpContext.Session.Set(nameof(CartViewModel), data);
        }

        private async Task<CartViewModel> GetCartAsync()
        {
            var cartData = GetCartData();
            ICollection<Concert> concertsInCart = new List<Concert>();
            if (cartData.Count > 0)
            {
                concertsInCart = await this.concertService.GetConcertsByIdAsync(cartData.Keys);
            }

            var concertCartData = concertsInCart.ToDictionary(concert => concert, concert => cartData[concert.Id]);
            return new CartViewModel(concertCartData);
        }

        #endregion
    }
}

﻿// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Models.ConcertContext;
using Relecloud.Models.Services;
using Relecloud.Web.CallCenter.Infrastructure;
using Relecloud.Web.CallCenter.ViewModels;

namespace Relecloud.Web.CallCenter.Controllers
{
    [Authorize]
    public class TicketController : Controller
    {
        #region Fields

        private readonly ILogger<TicketController> logger;
        private readonly IConcertContextService concertService;

        #endregion

        #region Constructors

        public TicketController(IConcertContextService concertService, ILogger<TicketController> logger)
        {
            this.concertService = concertService;
            this.logger = logger;
        }

        #endregion

        #region Index

        public async Task<IActionResult> Index(int currentPage)
        {
            try
            {
                var userId = this.User.GetUniqueId();
                var pagedResultModel = await this.concertService.GetAllTicketsAsync(userId, currentPage * TicketViewModel.DefaultPageSize, TicketViewModel.DefaultPageSize);

                return View(new TicketViewModel
                {
                    CurrentPage = currentPage,
                    TotalCount = pagedResultModel?.TotalCount ?? 0,
                    Tickets = pagedResultModel?.PageOfData ?? new List<Ticket>()
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unable to retrieve upcoming concerts");
                return View();
            }
        }

        #endregion
    }
}
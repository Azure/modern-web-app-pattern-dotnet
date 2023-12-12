using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.TokenCacheProviders.Distributed;
using Microsoft.Identity.Web.UI;
using Microsoft.IdentityModel.Logging;
using Microsoft.Net.Http.Headers;
using Polly;
using Polly.Contrib.WaitAndRetry;
using Polly.Extensions.Http;
using Relecloud.Models.ConcertContext;
using Relecloud.Models.Services;
using Relecloud.Web.Public.Infrastructure;
using Relecloud.Web.Public.Services;
using Relecloud.Web.Public.Services.MockServices;
using Relecloud.Web.Public.Services.RelecloudApiServices;
using Relecloud.Web.Services.ApiConcertService;
using Relecloud.Web.Services.MockServices;
using Relecloud.Web.Services.RelecloudApiServices;
using System.Diagnostics;

namespace Relecloud.Web.Public
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddHttpContextAccessor();
            services.Configure<RelecloudApiOptions>(Configuration.GetSection("PubApp:RelecloudApi"));
            services.AddOptions();
            AddAzureAdB2cServices(services);
            services.AddControllersWithViews();
            services.AddApplicationInsightsTelemetry(Configuration["App:Api:ApplicationInsights:ConnectionString"]);

            AddConcertContextService(services);
            AddConcertSearchService(services);
            AddTicketPurchaseService(services);
            AddAzureCacheForRedis(services);

            // Add support for session state.
            // NOTE: If there is a distibuted cache service (e.g. Redis) then this will be used to store session data.
            services.AddSession();
        }

        private void AddAzureCacheForRedis(IServiceCollection services)
        {
            if (!string.IsNullOrWhiteSpace(Configuration["App:RedisCache:ConnectionString"]))
            {
                services.AddStackExchangeRedisCache(options =>
                {
                    options.Configuration = Configuration["App:RedisCache:ConnectionString"];
                });
            }
            else
            {
                services.AddDistributedMemoryCache();
            }
        }

        private void AddTicketPurchaseService(IServiceCollection services)
        {
            var baseUri = Configuration["PubApp:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<ITicketPurchaseService, MockTicketPurchaseService>();
            }
            else
            {
                services.AddHttpClient<ITicketPurchaseService, RelecloudApiTicketPurchaseService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.Public");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private void AddConcertSearchService(IServiceCollection services)
        {
            var baseUri = Configuration["PubApp:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<IConcertSearchService, MockConcertSearchService>();
            }
            else
            {
                services.AddHttpClient<IConcertSearchService, RelecloudApiConcertSearchService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.Public");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
        {
            var delay = Backoff.DecorrelatedJitterBackoffV2(TimeSpan.FromMilliseconds(500), retryCount: 3);

            return HttpPolicyExtensions
              .HandleTransientHttpError()
              .WaitAndRetryAsync(delay);
        }

        private static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
        {
            int circuitTimeoutInSeconds = 30;
            if (Debugger.IsAttached)
            {
                circuitTimeoutInSeconds = 3;
            }

            return HttpPolicyExtensions
                .HandleTransientHttpError()
                .OrResult(msg => msg.StatusCode == System.Net.HttpStatusCode.NotFound)
                .CircuitBreakerAsync(5, TimeSpan.FromSeconds(circuitTimeoutInSeconds));
        }

        private void AddConcertContextService(IServiceCollection services)
        {
            string baseUri = Configuration["PubApp:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<IConcertContextService, MockConcertContextService>();
            }
            else
            {
                services.AddHttpClient<IConcertContextService, RelecloudApiConcertService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.Public");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private void AddAzureAdB2cServices(IServiceCollection services)
        {
            services.AddRazorPages().AddMicrosoftIdentityUI();

            services.AddAuthorization(options =>
            {
                options.AddPolicy(Roles.Administrator, authBuilder =>
                {
                    authBuilder.RequireRole(Roles.Administrator);
                });
            });

            var builder = services.AddMicrosoftIdentityWebAppAuthentication(Configuration, Constants.AzureAdB2C)
                    .EnableTokenAcquisitionToCallDownstreamApi(new string[] { Configuration["PubApp:RelecloudApi:Scope"] });

            // when using Microsoft.Identity.Web to retrieve an access token on behalf of the authenticated user
            // you should use a shared session state provider.
            // https://learn.microsoft.com/en-us/azure/active-directory-b2c/configure-authentication-sample-web-app-with-api?tabs=visual-studio#token-cache-for-a-web-app
            if (string.IsNullOrEmpty(Configuration["App:RedisCache:ConnectionString"]))
            {
                builder.AddInMemoryTokenCaches();
            }
            else
            {
                builder.AddDistributedTokenCaches();
                services.Configure<MsalDistributedTokenCacheAdapterOptions>(options =>
                {
                    options.DisableL1Cache = true;
                });
            }

            services.Configure<OpenIdConnectOptions>(Configuration.GetSection("AzureAdB2C"));
            services.Configure((Action<MicrosoftIdentityOptions>)(options =>
            {
                options.Events = new OpenIdConnectEvents
                {
                    OnTokenValidated = async ctx =>
                    {
                        await CreateOrUpdateUserInformation(ctx);
                    }
                };
            }));
        }

        private static async Task CreateOrUpdateUserInformation(TokenValidatedContext ctx)
        {
            try
            {
                if (ctx.Principal?.Identity is not null)
                {
                    // The user has signed in, ensure the information in the database is up-to-date.
                    var user = new User
                    {
                        Id = ctx.Principal.GetUniqueId(),
                        DisplayName = ctx.Principal.Identity.Name ?? "New User"
                    };

                    var concertService = ctx.HttpContext.RequestServices.GetRequiredService<IConcertContextService>();
                    await concertService.CreateOrUpdateUserAsync(user);
                }
            }
            catch (Exception ex)
            {
                var logger = ctx.HttpContext.RequestServices.GetRequiredService<ILogger<Startup>>();
                logger.LogError(ex, "Unhandled exception from Startup.CreateOrUpdateUserInformation");
            }
        }

        public void Configure(WebApplication app, IWebHostEnvironment env)
        {

            // Configure the HTTP request pipeline.
            if (!env.IsDevelopment())
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            else if (Debugger.IsAttached)
            {
                // By default, we do not include any potential PII (personally identifiable information) in our exceptions in order to be in compliance with GDPR.
                // https://aka.ms/IdentityModel/PII
                IdentityModelEventSource.ShowPII = true;
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseSession(); // required for carts

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
                endpoints.MapRazorPages();
            });
        }
    }
}

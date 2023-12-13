using Relecloud.TicketRenderer;
using Relecloud.TicketRenderer.Services;

var builder = WebApplication.CreateBuilder(args);

// TODO - Add Storage and Service Bus checks here
builder.Services.AddHealthChecks();
builder.Services.AddHostedService<TicketRenderRequestHandler>();
builder.Services.AddScoped<IImageStorage, AzureImageStorage>();

var app = builder.Build();

app.MapHealthChecks("/health");

await app.RunAsync();
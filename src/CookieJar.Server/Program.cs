using CookieJar.Server;
using CookieJar.Server.Data;
using CookieJar.Server.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();

builder.AddNpgsqlDbContext<CookieJarDbContext>("cookiejardb", settings =>
    settings.DisableRetry = false);

builder.AddRabbitMQClient("messaging");

builder.Services.AddOptions<CookieJarOptions>()
    .BindConfiguration(CookieJarOptions.SectionName);

builder.Services.AddDbContextFactory<CookieJarDbContext>();
builder.Services.AddSingleton<CookieJarService>();
builder.Services.AddHostedService<CookieSensorConsumer>();

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
    app.MapOpenApi();

// Auto-migrate on startup
await using (var scope = app.Services.CreateAsyncScope())
{
    var db = scope.ServiceProvider.GetRequiredService<CookieJarDbContext>();
    await db.Database.MigrateAsync();
}

var api = app.MapGroup("/api/cookiejar");

api.MapGet("/level", async (CookieJarService service) =>
{
    var level = await service.GetLevelAsync();
    return Results.Ok(new { level });
});

api.MapPost("/refill", async (CookieJarService service) =>
{
    var level = await service.RefillAsync();
    return Results.Ok(new { level });
});

api.MapGet("/level/stream", async (CookieJarService service, HttpContext ctx, CancellationToken ct) =>
{
    ctx.Response.Headers.ContentType = "text/event-stream";
    ctx.Response.Headers.CacheControl = "no-cache";
    ctx.Response.Headers.Connection = "keep-alive";

    var channel = service.Subscribe();
    var currentLevel = await service.GetLevelAsync();
    await ctx.Response.WriteAsync($"data: {currentLevel}\n\n", ct);
    await ctx.Response.Body.FlushAsync(ct);

    try
    {
        await foreach (var level in channel.Reader.ReadAllAsync(ct))
        {
            await ctx.Response.WriteAsync($"data: {level}\n\n", ct);
            await ctx.Response.Body.FlushAsync(ct);
        }
    }
    finally
    {
        service.Unsubscribe(channel);
    }
});

app.MapDefaultEndpoints();
app.UseFileServer();
app.Run();

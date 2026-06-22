using System.Threading.Channels;
using CookieJar.Server.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CookieJar.Server.Services;

public class CookieJarService(
    IDbContextFactory<CookieJarDbContext> dbFactory,
    IOptionsMonitor<CookieJarOptions> options,
    ILogger<CookieJarService> logger)
{
    private readonly List<Channel<int>> _subscribers = [];
    private readonly Lock _lock = new();

    public async Task<int> GetLevelAsync()
    {
        await using var db = await dbFactory.CreateDbContextAsync();
        var state = await db.CookieJarStates.FirstAsync();
        return state.Level;
    }

    public async Task<int> TakeCookieAsync(int amount = 5)
    {
        await using var db = await dbFactory.CreateDbContextAsync();
        var state = await db.CookieJarStates.FirstAsync();
        state.Level = Math.Max(0, state.Level - amount);
        state.LastUpdated = DateTime.UtcNow;
        await db.SaveChangesAsync();
        logger.LogInformation("Cookie taken, level now {Level}", state.Level);
        Broadcast(state.Level);
        return state.Level;
    }

    public async Task<int> RefillAsync()
    {
        await using var db = await dbFactory.CreateDbContextAsync();
        var state = await db.CookieJarStates.FirstAsync();
        state.Level = options.CurrentValue.Capacity;
        state.LastUpdated = DateTime.UtcNow;
        await db.SaveChangesAsync();
        logger.LogInformation("Cookie jar refilled to {Capacity}", state.Level);
        Broadcast(state.Level);
        return state.Level;
    }

    public Channel<int> Subscribe()
    {
        var channel = Channel.CreateUnbounded<int>();
        lock (_lock) _subscribers.Add(channel);
        return channel;
    }

    public void Unsubscribe(Channel<int> channel)
    {
        lock (_lock) _subscribers.Remove(channel);
        channel.Writer.TryComplete();
    }

    private void Broadcast(int level)
    {
        lock (_lock)
        {
            foreach (var channel in _subscribers)
                channel.Writer.TryWrite(level);
        }
    }
}

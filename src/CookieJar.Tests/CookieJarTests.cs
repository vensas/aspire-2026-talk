using System.Net.Http.Json;
using System.Text;
using Aspire.Hosting;
using Aspire.Hosting.Testing;
using RabbitMQ.Client;

namespace CookieJar.Tests;

/// <summary>
/// End-to-end tests against the running AppHost. Every test starts with a jar at level 100.
/// </summary>
[Collection(CookieJarAppFixture.Collection)]
public sealed class CookieJarTests(CookieJarAppFixture fixture) : IAsyncLifetime
{
    private static readonly TimeSpan EventTimeout = TimeSpan.FromSeconds(30);
    private static CancellationToken CancellationToken => TestContext.Current.CancellationToken;

    public async ValueTask InitializeAsync()
    {
        // Direct database access through the connection string Aspire resolved for the test
        await using var command = fixture.Database.CreateCommand("""UPDATE "CookieJarStates" SET "Level" = 100""");
        await command.ExecuteNonQueryAsync(CancellationToken);
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;

    [Fact(Timeout = 120_000)]
    public async Task Refill_SetsLevelToCapacityParameter()
    {
        // Goes through the Aspire proxy, like any other client
        using var client = fixture.App.CreateHttpClient("server");

        var response = await client.PostAsync("/api/cookiejar/refill", null, CancellationToken);

        response.EnsureSuccessStatusCode();
        Assert.Equal(CookieJarAppFixture.Capacity, (await response.Content.ReadFromJsonAsync<LevelResponse>(CancellationToken))!.Level);
    }

    [Fact(Timeout = 120_000)]
    public async Task CookieTakenEvent_LowersLevel_OnBothReplicas()
    {
        await PublishCookieTakenAsync(amount: 7);

        // RabbitMQ gives the event to one replica — both must see the new level from the shared database
        foreach (var replica in fixture.Replicas)
        {
            using var client = new HttpClient { BaseAddress = replica };
            Assert.Equal(93, await WaitForLevelAsync(client, 93));
        }
    }

    /// <summary>
    /// Fails on purpose: the SSE subscriptions live in memory per replica (<c>Channel&lt;int&gt;</c>), so only the
    /// replica that consumed the event notifies its clients. Run it with <c>dotnet run -- -explicit only</c>.
    /// </summary>
    [Fact(Explicit = true, Timeout = 120_000)]
    public async Task LevelStream_OnEveryReplica_ReceivesEveryChange()
    {
        var streams = fixture.Replicas.Select(ReadLevelStreamAsync).ToList();
        // Let both SSE connections receive their initial level first
        await Task.Delay(TimeSpan.FromSeconds(1), CancellationToken);

        for (var i = 0; i < 4; i++)
            await PublishCookieTakenAsync(amount: 1);

        foreach (var stream in streams)
            Assert.Equal([100, 99, 98, 97, 96], await stream);
    }

    private async Task PublishCookieTakenAsync(int amount)
    {
        var factory = new ConnectionFactory { Uri = new Uri(fixture.MessagingConnectionString) };
        await using var connection = await factory.CreateConnectionAsync(CancellationToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: CancellationToken);
        await channel.BasicPublishAsync("", "cookie-taken", Encoding.UTF8.GetBytes($$"""{ "Amount": {{amount}} }"""), CancellationToken);
    }

    private static async Task<int> WaitForLevelAsync(HttpClient client, int expected)
    {
        var deadline = DateTimeOffset.UtcNow + EventTimeout;
        while (true)
        {
            var level = (await client.GetFromJsonAsync<LevelResponse>("/api/cookiejar/level", CancellationToken))!.Level;
            if (level == expected || DateTimeOffset.UtcNow > deadline)
                return level;
            await Task.Delay(TimeSpan.FromMilliseconds(250), CancellationToken);
        }
    }

    /// <summary>Reads the SSE stream until the initial level and 4 changes arrived, or the timeout is over.</summary>
    private static async Task<List<int>> ReadLevelStreamAsync(Uri replica)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(CancellationToken);
        cts.CancelAfter(EventTimeout);
        using var client = new HttpClient { BaseAddress = replica };
        var levels = new List<int>();
        try
        {
            await using var stream = await client.GetStreamAsync("/api/cookiejar/level/stream", cts.Token);
            using var reader = new StreamReader(stream);
            while (levels.Count < 5 && await reader.ReadLineAsync(cts.Token) is { } line)
            {
                if (line.StartsWith("data: ", StringComparison.Ordinal))
                    levels.Add(int.Parse(line["data: ".Length..]));
            }
        }
        catch (OperationCanceledException)
        {
            // Return what arrived until the timeout
        }

        return levels;
    }

    private sealed record LevelResponse(int Level);
}

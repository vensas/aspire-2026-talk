using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Postgres;
using Aspire.Hosting.Testing;
using Npgsql;

namespace CookieJar.Tests;

[CollectionDefinition(CookieJarAppFixture.Collection)]
public sealed class CookieJarAppCollection : ICollectionFixture<CookieJarAppFixture>;

/// <summary>
/// Starts the real AppHost one time for all tests: 2 server replicas, PostgreSQL and RabbitMQ.
/// </summary>
public sealed class CookieJarAppFixture : IAsyncLifetime
{
    public const string Collection = "CookieJar app";
    public const int Capacity = 42;
    private static readonly TimeSpan StartTimeout = TimeSpan.FromMinutes(5);

    public DistributedApplication App { get; private set; } = null!;
    public IReadOnlyList<Uri> Replicas { get; private set; } = [];
    public IReadOnlyList<string> ReplicaResourceIds { get; private set; } = [];
    public NpgsqlDataSource Database { get; private set; } = null!;
    public string MessagingConnectionString { get; private set; } = null!;

    public async ValueTask InitializeAsync()
    {
        using var cts = new CancellationTokenSource(StartTimeout);

        // Parameters come in as configuration — no user secrets needed on the build agent
        var builder = await DistributedApplicationTestingBuilder.CreateAsync<Projects.CookieJar_AppHost>(
            ["Parameters:rabbitmq-password=e2e-test", $"Parameters:cookie-jar-capacity={Capacity}"], cts.Token);

        // No UI and no random sensor: the tests send the cookie-taken events themselves
        // (including their npm/pip installer resources)
        foreach (var resource in builder.Resources.Where(r => r is PgAdminContainerResource
                     || r.Name.StartsWith("frontend") || r.Name.StartsWith("cookie-sensor")).ToList())
            builder.Resources.Remove(resource);

        // Start with an empty database. Do not touch the data volume of the local development environment.
        var postgres = builder.Resources.Single(r => r.Name == "postgres");
        foreach (var mount in postgres.Annotations.OfType<ContainerMountAnnotation>().ToList())
            postgres.Annotations.Remove(mount);

        App = await builder.BuildAsync(cts.Token);
        await App.StartAsync(cts.Token);
        await App.ResourceNotifications.WaitForResourceHealthyAsync("server", cts.Token);

        (ReplicaResourceIds, Replicas) = await WaitForReplicasAsync(expected: 2, cts.Token);
        Database = NpgsqlDataSource.Create(await App.GetConnectionStringAsync("cookiejardb", cts.Token)
                                           ?? throw new InvalidOperationException("The connection string of cookiejardb is missing."));
        MessagingConnectionString = await App.GetConnectionStringAsync("messaging", cts.Token)
                                    ?? throw new InvalidOperationException("The connection string of messaging is missing.");
    }

    /// <summary>
    /// The "http" endpoint of the server is the Aspire proxy, which sends each request to any replica.
    /// ASPNETCORE_URLS has the port of one replica.
    /// </summary>
    private async Task<(IReadOnlyList<string> ResourceIds, IReadOnlyList<Uri> Urls)> WaitForReplicasAsync(int expected, CancellationToken ct)
    {
        var urls = new Dictionary<string, Uri>();
        await foreach (var e in App.ResourceNotifications.WatchAsync(ct))
        {
            if (e.Resource.Name != "server" || e.Snapshot.State?.Text != KnownResourceStates.Running)
                continue;

            var aspNetCoreUrls = e.Snapshot.EnvironmentVariables.FirstOrDefault(v => v.Name == "ASPNETCORE_URLS")?.Value;
            var url = aspNetCoreUrls?.Split(';').FirstOrDefault(u => u.StartsWith("http://", StringComparison.Ordinal));
            if (url is null)
                continue;

            urls[e.ResourceId] = new Uri(url);
            if (urls.Count == expected)
            {
                var ordered = urls.OrderBy(u => u.Key).ToList();
                return ([.. ordered.Select(u => u.Key)], [.. ordered.Select(u => u.Value)]);
            }
        }

        throw new OperationCanceledException();
    }

    public async ValueTask DisposeAsync()
    {
        if (Database is not null)
            await Database.DisposeAsync();
        if (App is not null)
            await App.DisposeAsync();
    }
}

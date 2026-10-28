using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;

namespace CookieJar.Tests;

/// <summary>
/// Checks the app model of the AppHost without starting anything — no Docker needed, runs in milliseconds.
/// </summary>
public sealed class AppModelTests
{
    private static CancellationToken CancellationToken => TestContext.Current.CancellationToken;

    [Fact]
    public async Task Server_RunsTwoReplicas_WithHealthCheck()
    {
        await using var builder = await DistributedApplicationTestingBuilder.CreateAsync<Projects.CookieJar_AppHost>(
            ["Parameters:rabbitmq-password=unused"], CancellationToken);

        var server = builder.Resources.OfType<ProjectResource>().Single(r => r.Name == "server");

        Assert.Equal(2, server.GetReplicaCount());
        Assert.Contains(server.Annotations.OfType<HealthCheckAnnotation>(), a => a.Key.StartsWith("server_"));
    }

    [Fact]
    public async Task Server_WaitsForDatabaseAndMessaging()
    {
        await using var builder = await DistributedApplicationTestingBuilder.CreateAsync<Projects.CookieJar_AppHost>(
            ["Parameters:rabbitmq-password=unused"], CancellationToken);

        var server = builder.Resources.Single(r => r.Name == "server");
        var waitsFor = server.Annotations.OfType<WaitAnnotation>().Select(a => a.Resource.Name);

        Assert.Equivalent(new[] { "cookiejardb", "messaging" }, waitsFor);
    }

    [Fact]
    public async Task CapacityParameter_ReadsConfiguration()
    {
        await using var builder = await DistributedApplicationTestingBuilder.CreateAsync<Projects.CookieJar_AppHost>(
            ["Parameters:rabbitmq-password=unused", "Parameters:cookie-jar-capacity=80"], CancellationToken);

        var capacity = builder.Resources.OfType<ParameterResource>().Single(r => r.Name == "cookie-jar-capacity");

        Assert.Equal("80", await capacity.GetValueAsync(CancellationToken));
    }
}

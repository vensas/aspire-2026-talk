using Aspire.Hosting.Docker.Resources.ServiceNodes;

var builder = DistributedApplication.CreateBuilder(args);

#region Publishing Configuration

switch (Environment.GetEnvironmentVariable("PUBLISH_TARGET"))
{
    case "docker-compose":
        builder.AddDockerComposeEnvironment("docker-compose")
            .ConfigureComposeFile(compose =>
            {
                compose.Services["postgres"].Healthcheck = new Healthcheck
                {
                    Test = ["CMD-SHELL", "pg_isready -U postgres"],
                    Interval = "5s",
                    Timeout = "5s",
                    Retries = 5,
                    StartPeriod = "10s",
                };
                compose.Services["messaging"].Healthcheck = new Healthcheck
                {
                    Test = ["CMD", "rabbitmq-diagnostics", "-q", "ping"],
                    Interval = "10s",
                    Timeout = "5s",
                    Retries = 5,
                    StartPeriod = "30s",
                };
                compose.Services["cookie-sensor"].DependsOn["messaging"].Condition = "service_healthy";
                compose.Services["server"].DependsOn["postgres"].Condition = "service_healthy";
                compose.Services["server"].DependsOn["messaging"].Condition = "service_healthy";
            });
        break;
    case "kubernetes":
        builder.AddKubernetesEnvironment("kubernetes");
        break;
    case "kamal":
        // Target VM and registry are passed in by deploy/kamal/2-publish.sh (Multipass VM, local registry)
        var kamalServer = builder.Configuration["KAMAL_SERVER"] ?? "192.168.64.2";
        builder.AddKamalEnvironment("kamal")
            .WithServers(kamalServer)
            .WithRegistry(builder.Configuration["KAMAL_REGISTRY"] ?? "192.168.64.1:5001", "unused")
            .WithProxyHostSuffix($"{kamalServer}.nip.io")
            .WithProperties(kamal =>
            {
                kamal.SshUser = "ubuntu";
                kamal.BuilderArch = "arm64";
                kamal.ImageNamespace = "cookiejar";
            })
            .ConfigureDeployConfig(config =>
            {
                // Local VM without a public domain — no Let's Encrypt
                if (config.Proxy is not null)
                    config.Proxy.Ssl = false;
            });
        break;
}

#endregion

var rabbitPassword = builder.AddParameter("rabbitmq-password", secret: true);
// AddParameter(name, value) would be a constant — read configuration first, fall back to 100
var capacity = builder.AddParameter("cookie-jar-capacity",
    builder.Configuration["Parameters:cookie-jar-capacity"] ?? "100", publishValueAsDefault: true);

var postgres = builder.AddPostgres("postgres")
    .WithPgAdmin()
    .WithDataVolume();

var db = postgres.AddDatabase("cookiejardb");

var rabbitmq = builder.AddRabbitMQ("messaging", password: rabbitPassword)
    .WithManagementPlugin();

var server = builder.AddProject<Projects.CookieJar_Server>("server")
    .WithReference(db)
    .WaitFor(db)
    .WithReference(rabbitmq)
    .WaitFor(rabbitmq)
    .WithEnvironment("CookieJar__Capacity", capacity)
    .WithHttpHealthCheck("/health")
    .WithReplicas(2)
    .WithExternalHttpEndpoints()
    .PublishAsKamalService((_, config) => config.Proxy!.Healthcheck = new() { Path = "/health" });

server.WithUrl($"{server.GetEndpoint("http")}/scalar", "Scalar");

// Declared after the server: Kamal makes the first app the primary one that owns all accessories
builder.AddPythonApp("cookie-sensor", "../cookie-sensor", "sensor.py")
    .WithReference(rabbitmq)
    .WaitFor(rabbitmq);

if (builder.ExecutionContext.IsRunMode)
{
    builder.AddViteApp("frontend", "../frontend")
        .WithReference(server)
        .WaitFor(server);
}
else
{
    builder.AddDockerfile("frontend", "../frontend")
        .WithHttpEndpoint(port: 3000, targetPort: 80)
        .WithEnvironment("SERVER_URL", server.GetEndpoint("http"))
        .WithExternalHttpEndpoints()
        .WaitFor(server)
        .PublishAsKamalService((_, config) => config.Proxy!.Healthcheck = new() { Path = "/" });
}

await builder.Build().RunAsync();

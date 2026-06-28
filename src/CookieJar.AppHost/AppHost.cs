using Aspire.Hosting.Docker.Resources.ServiceNodes;
using Aspire.Hosting.Pipelines;
using CookieJar.AppHost.Publishing;


var builder = DistributedApplication.CreateBuilder(args);

builder.AddDockerComposeEnvironment("docker-compose")
    .ConfigureComposeFile(compose =>
    {
        compose.Services["messaging"].Healthcheck = new Healthcheck
        {
            Test = ["CMD", "rabbitmq-diagnostics", "-q", "ping"],
            Interval = "10s",
            Timeout = "5s",
            Retries = 5,
            StartPeriod = "30s",
        };

        compose.Services["cookie-sensor"].DependsOn["messaging"].Condition = "service_healthy";
    });

// Kamal: only registered in publish mode, triggered explicitly via --step generate-kamal-config
if (builder.ExecutionContext.IsPublishMode)
{
    builder.AddResource(new KamalDeploymentResource("kamal"))
        .WithPipelineStepFactory(KamalPipelineStep.Create);
}

var rabbitPassword = builder.AddParameter("rabbitmq-password", secret: true);
var capacity = builder.AddParameter("cookie-jar-capacity", "100");

var postgres = builder.AddPostgres("postgres")
    .WithPgAdmin()
    .WithDataVolume();

var db = postgres.AddDatabase("cookiejardb");

var rabbitmq = builder.AddRabbitMQ("messaging", password: rabbitPassword)
    .WithManagementPlugin()
    .WithDataVolume();

builder.AddPythonApp("cookie-sensor", "../cookie-sensor", "sensor.py")
    .WithReference(rabbitmq) // Injects RabbitMQ connection string into configuration
    .WaitFor(rabbitmq);

var server = builder.AddProject<Projects.CookieJar_Server>("server")
    .WithReference(db)
    .WaitFor(db)
    .WithReference(rabbitmq) // Injects RabbitMQ connection string into configuration
    .WaitFor(rabbitmq)
    .WithEnvironment("CookieJar__Capacity", capacity)
    .WithHttpHealthCheck("/health")
    .WithReplicas(2)
    .WithExternalHttpEndpoints();

if (builder.ExecutionContext.IsRunMode)
{
    builder.AddViteApp("frontend", "../frontend")
        .WithReference(server)
        .WaitFor(server);
}
else
{
    builder.AddDockerfile("frontend", "../frontend")
        .WithHttpEndpoint(port: 80, targetPort: 80)
        .WithEnvironment("SERVER_URL", server.GetEndpoint("http"))
        .WithExternalHttpEndpoints()
        .WaitFor(server);
}

await builder.Build().RunAsync();

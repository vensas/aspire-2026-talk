var builder = DistributedApplication.CreateBuilder(args);

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
    .WithExternalHttpEndpoints();

var frontend = builder.AddViteApp("frontend", "../frontend")
    .WithReference(server)
    .WaitFor(server);

server.PublishWithContainerFiles(frontend, "wwwroot");

await builder.Build().RunAsync();

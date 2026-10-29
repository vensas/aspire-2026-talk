# Speaker notes — Aspire in Practice, IT-Tage 2026

Thursday 10 December 2026, 09:00–09:45, Frankfurt. The slides do not show the demo commands; they are here.

| # | Slide | Notes |
|---|---|---|
| 1 | Cover | Practical experience, no marketing. Aspire 13.6 on .NET 10: local development, tests with Aspire.Hosting.Testing, deployment, MCP. |
| 2 | About me | Keep it short. vensas: a small team for .NET and web, customers with 50–500 employees. |
| 3 | From Tye to Aspire | Tye had the same idea. GA in May 2024. Since 2025 Aspire has its own release cycle. |
| 4 | The demo app | The sensor takes 3–10 cookies every 2–10 s. The event goes through RabbitMQ to the server, which writes PostgreSQL and pushes SSE to the page. Three languages in one AppHost. |
| 5 | One AppHost | **Demo:** `aspire run`. Show the graph view: two server replicas, the installer resources that Aspire 13.6 adds for npm and pip. |
| 6 | Dashboard | **Demo:** the traces page. RabbitMQ is a competing consumer — the replicas take turns. Remember this for the SSE limit on the test slide. |
| 7 | Parameters | `secret: true` has no default: user secrets or an environment variable. `AddParameter(name, "100")` is a constant and ignores the configuration. Read the configuration first. `CapacityParameter_ReadsConfiguration` and the refill test guard this. |
| 8 | How Aspire works | DCP is a Go binary (dcp + dcpctrl) with a Kubernetes-like API. The AppHost talks to it with the KubernetesClient package — not gRPC. DCP also starts the dashboard as a separate process; the services send OTLP to it directly. No ports in the code: WithReference and service discovery give them as environment variables. WaitFor: show the Starting → Running → Healthy states in the dashboard. |
| 9 | Project A | Anonymized. The upstream fake is a minimal API in the test process and counts the requests. `docker pause`, not `stop` — stop deletes the bucket. Replica logs go to a custom ILoggerProvider ("Acquired the migration lock" two times). |
| 10 | Project B | Anonymized. The AppHost starts one time per run (xUnit v3 AssemblyFixture). Playwright users come from route interception of the UI configuration. |
| 11 | Aspire.Hosting.Testing | The test project references the AppHost like a library. Model tests run in the PR build; E2E tests start real containers. Compare: with Testcontainers or WebApplicationFactory you build the topology again in the test. |
| 12 | Change the AppHost | Remove PgAdmin, the frontend, the sensor and their installer resources. Remove the data volume. |
| 13 | Two replicas in the test | **Demo:** `dotnet test src/CookieJar.Tests`, then `dotnet run --project src/CookieJar.Tests -- -explicit only`. The SSE limit is kept on purpose as a discussion point: a fix is a fanout exchange or Postgres LISTEN/NOTIFY. `BothReplicas_MigrateUnderTheLock` checks the advisory lock around MigrateAsync through the replica logs. |
| 14 | Docker Compose | **Demo:** `deploy/docker-compose/1-publish.sh` … `3-deploy.sh`. Azure: `azd up` generates Bicep — not in the demo. |
| 15 | Kubernetes and Kamal | **Demo:** `deploy/kubernetes/*` and `deploy/kamal/*`. Kubernetes output is a preview: no ingress, secrets need work. Kamal: from 37signals, deploy without Kubernetes. `Vensas.Aspire.Hosting.Kamal` is an open-source compute environment, like Compose and Kubernetes. |
| 16 | Kamal mapping | Each app gets its own Kamal config; the accessories belong to the first app — thus the sensor comes after the server in the AppHost. Podman: the scripts build the images, then `kamal deploy --skip-push`. |
| 17 | Aspire MCP | **Demo:** ask the agent why replica 2 does not stream the new level. `aspire agent init` sets up the MCP server. |
| 18 | TL;DR | Local development and Azure: use it now. Other targets: plan the work, or help to build them. |
| 19 | Questions | The QR code links to this repository. The last link is the Kamal package. Feedback through the IT-Tage rating. |

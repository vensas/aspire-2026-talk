# Speaker notes — Aspire in Practice, IT-Tage 2026

Thursday 10 December 2026, 09:00–09:45, Frankfurt. The slides do not show the demo commands; they are here.

| # | Slide | Notes |
|---|---|---|
| 1 | Cover | Practical experience, no marketing. Aspire 13.6 on .NET 10. New since DWX: Aspire.Hosting.Testing, and Kamal as a NuGet package. |
| 2 | About me | Keep it short. vensas: a small team for .NET and web, customers with 50–500 employees. |
| 3 | From Tye to Aspire | Tye had the same idea. GA in May 2024. Since 2025 Aspire has its own release cycle. |
| 4 | The demo app | The sensor takes 3–10 cookies every 2–10 s. The event goes through RabbitMQ to the server, which writes PostgreSQL and pushes SSE to the page. Three languages in one AppHost. |
| 5 | One AppHost | **Demo:** `aspire run`. Show the graph view: two server replicas, the installer resources that Aspire 13.6 adds for npm and pip. |
| 6 | Dashboard | **Demo:** the traces page. RabbitMQ is a competing consumer — the replicas take turns. Remember this for the SSE bug. |
| 7 | Parameters | `secret: true` has no default: user secrets or an environment variable. The DWX version had `AddParameter(name, "100")` — a constant. Nobody saw it until a test expected 42. |
| 8 | How Aspire works | DCP is a Go binary with a Kubernetes-like API. The dashboard gets OTLP from the services. No ports in the code: WithReference gives them as environment variables. |
| 9 | Aspire.Hosting.Testing | The test project references the AppHost like a library. Model tests run in the PR build; E2E tests start real containers. Compare: with Testcontainers or WebApplicationFactory you build the topology again in the test. |
| 10 | Change the AppHost | Remove PgAdmin, the frontend, the sensor and their installer resources. Remove the data volume. |
| 11 | The tests found two bugs | **Demo:** `dotnet test src/CookieJar.Tests`, then `dotnet run --project src/CookieJar.Tests -- -explicit only`. The SSE bug stays open on purpose: a fix is a fanout exchange or Postgres LISTEN/NOTIFY. `BothReplicas_MigrateUnderTheLock` shows the advisory lock around MigrateAsync. |
| 12 | Project A | Anonymized. The upstream fake is a minimal API in the test process and counts the requests. `docker pause`, not `stop` — stop deletes the bucket. Replica logs go to a custom ILoggerProvider ("Acquired the migration lock" two times). |
| 13 | Project B | Anonymized. The AppHost starts one time per run (xUnit v3 AssemblyFixture). Playwright users come from route interception of the UI configuration. |
| 14 | Docker Compose | **Demo:** `deploy/docker-compose/1-publish.sh` … `3-deploy.sh`. Azure: `azd up` generates Bicep — not in the demo. |
| 15 | Kubernetes and Kamal | **Demo:** `deploy/kubernetes/*` and `deploy/kamal/*`. Kubernetes output is a preview: no ingress, secrets need work. Kamal: from 37signals, deploy without Kubernetes. The DWX custom step is now `Vensas.Aspire.Hosting.Kamal`. |
| 16 | Custom step → package | Each app gets its own Kamal config; the accessories belong to the first app — thus the sensor comes after the server in the AppHost. Podman: the scripts build the images, then `kamal deploy --skip-push`. |
| 17 | Aspire MCP | **Demo:** ask the agent why replica 2 does not stream the new level. `aspire agent init` sets up the MCP server. |
| 18 | TL;DR | Local development and Azure: use it now. Other targets: plan the work, or help to build them. |
| 19 | Questions | QR codes: this repository and the Kamal package. Feedback through the IT-Tage rating. |

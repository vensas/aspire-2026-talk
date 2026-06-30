> **Sync Notice:** This file is mirrored in `AGENTS.md`. When updating this file, also update `AGENTS.md` to keep instructions consistent across AI assistants.

DO create demo code in `src`
DO keep `AGENTS.md`, `CLAUDE.md`, and `README.md` up to date with the latest implementations.
DO NOT include the content of `CLAUDE.md` in the presentation outline.

## Demo project — CookieJar ("Keksdose")

A small distributed app that tracks the fill level of an office cookie jar in real time. UI and labels are in German. Three languages/runtimes to demonstrate Aspire's tech-stack independence.

`src/` contains the Aspire demo app (Aspire SDK 13.4.6, net10.0). `aspire.config.json` in `src/` points the Aspire CLI at the AppHost.

### Services

| Component | Path | Technology | Role |
|---|---|---|---|
| `CookieJar.AppHost` | `src/CookieJar.AppHost` | Aspire AppHost | Wires all resources; publish targets |
| `CookieJar.Server` | `src/CookieJar.Server` | ASP.NET Core + EF Core | REST + SSE API, PostgreSQL, RabbitMQ consumer |
| `frontend` | `src/frontend` | React + Vite | Live fill-level display; refill button |
| `cookie-sensor` | `src/cookie-sensor` | Python + pika | Simulates cookies being taken |
| `postgres` | — | PostgreSQL + PgAdmin | Persistent state |
| `messaging` | — | RabbitMQ + management plugin | Queue: `cookie-taken` |

### Data model

Single table `CookieJarStates`, always exactly one row (Id=1), seeded at Level=100:

```csharp
record CookieJarState { int Id; int Level; DateTime LastUpdated; }
```

### Server API (`/api/cookiejar/`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/level` | Returns `{ level: int }` |
| `POST` | `/refill` | Resets level to `CookieJarOptions.Capacity`; returns `{ level: int }` |
| `GET` | `/level/stream` | SSE stream — emits current level on connect, then on every state change |
| `GET` | `/health` | Readiness check (all health checks) |
| `GET` | `/alive` | Liveness check (`live`-tagged checks only) |
| `GET` | `/scalar` | Scalar API reference UI |

SSE is powered by in-memory `Channel<int>` subscriptions in `CookieJarService` — no SignalR or external broker involved.

### Capacity parameter

`CookieJar__Capacity` env var → bound to `CookieJarOptions.Capacity` (default 100). Injected by the AppHost:

```csharp
var capacity = builder.AddParameter("cookie-jar-capacity", "100");
server.WithEnvironment("CookieJar__Capacity", capacity);
```

### Cookie sensor

Publishes to queue `cookie-taken` (durable) every 2–10 s, taking 3–10 cookies per event:

```json
{ "Amount": 7 }
```

Reads `ConnectionStrings__messaging` from the environment (Aspire injects this).

### Frontend

- Connects to SSE on load (`/api/cookiejar/level/stream`); refill button POSTs to `/api/cookiejar/refill`
- Run mode: Vite dev server (proxies `/api/` to the server via Aspire service reference)
- Publish mode: Nginx Docker container; `SERVER_URL` env var points nginx proxy to the server

### Service defaults (`Extensions.cs`)

`AddServiceDefaults()` wires: OpenTelemetry (traces + metrics + logs via OTLP if `OTEL_EXPORTER_OTLP_ENDPOINT` is set), default health checks, service discovery, and standard HTTP resilience.

### AppHost highlights

- Server: `WithReplicas(2)`, `WithHttpHealthCheck("/health")`, `WithExternalHttpEndpoints()`
- PgAdmin and RabbitMQ management plugin included in run mode

## Running locally

```sh
dotnet run --project src/CookieJar.AppHost
```

Aspire starts all resources, runs DB migrations automatically, and opens the dashboard.

## Required setup before running

```sh
# Required
dotnet user-secrets set "Parameters:rabbitmq-password" "<password>" --project src/CookieJar.AppHost

# Optional — override capacity (default 100)
dotnet user-secrets set "Parameters:cookie-jar-capacity" "80" --project src/CookieJar.AppHost
```

Python sensor venv at `src/cookie-sensor/.venv` is pre-populated. To recreate:

```sh
cd src/cookie-sensor && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

## EF Core migrations

Migrations live in `CookieJar.Server/Migrations/`. After changing `CookieJarDbContext` or `CookieJarState`:

```sh
dotnet ef migrations add <Name> --project src/CookieJar.Server
```

Do NOT use dynamic values (e.g. `DateTime.UtcNow`) in `HasData` seed calls — use static hardcoded values.

## Build

```sh
dotnet build src/CookieJar.sln
```

## Publishing / Deployment

Three publish targets wired in `AppHost.cs` via `PUBLISH_TARGET` env var:

| `PUBLISH_TARGET` | Mechanism | Notes |
|---|---|---|
| `docker-compose` | `AddDockerComposeEnvironment` | Stable; health checks patched by `2-fix.sh` |
| `kubernetes` | `AddKubernetesEnvironment` | Preview; Helm chart, volume name dots + probes patched by `2-fix.sh` |
| `kamal` | Custom `KamalPipelineStep` | Experimental, not an official Aspire provider |

**Kamal publisher** (`src/CookieJar.AppHost/Publishing/KamalPublisher.cs`): custom Aspire pipeline step (`Aspire.Hosting.Pipelines`, experimental) that walks the resource model and generates `config/deploy.yml` + `.kamal/secrets.example`. The `KamalDeploymentResource` carries `ServiceName`, `Architecture`, and `ExtraSecretEnvVars`.

Pre-generated artifacts and numbered shell scripts live in `deploy/` — see `deploy/README.md`.

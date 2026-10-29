> **Sync Notice:** This file is mirrored in `AGENTS.md`. When updating this file, also update `AGENTS.md` to keep instructions consistent across AI assistants.

DO create demo code in `src`
DO keep `AGENTS.md`, `CLAUDE.md`, and `README.md` up to date with the latest implementations.
DO NOT include the content of `CLAUDE.md` in the presentation outline.

## Demo project — CookieJar ("Keksdose")

A small distributed app that tracks the fill level of an office cookie jar in real time. UI and labels are in German. Three languages/runtimes to demonstrate Aspire's tech-stack independence.

`src/` contains the Aspire demo app (Aspire SDK 13.6.4, net10.0). `aspire.config.json` in `src/` points the Aspire CLI at the AppHost.

### Talk versions

| Event | Slides | Demo state |
|---|---|---|
| DWX 2026 (30.06.2026) | `docs/aspire-in-der-praxis-dwx-2026-06-30.html` (+ `.pdf`) | git tag `dwx-2026` (Aspire 13.4.6, custom Kamal pipeline step) — DO NOT modify the DWX slides |
| IT-Tage 2026 (Do 10.12.2026, 09:00–09:45, Frankfurt) | `docs/aspire-in-practice-it-tage-2026-12-10.yaml` → `.pdf` (English, ASD-STE100), speaker notes in `docs/aspire-in-practice-it-tage-2026-12-10-notes.md` | current `src/` (Aspire 13.6.4, `Vensas.Aspire.Hosting.Kamal`, `CookieJar.Tests`) |

All decks live in `docs/`, named `<title>-<event>-<date>` like in `../playwright-2026-talk`. `docs/avatar.png` and `docs/dwx-feedback-qr-code.png` belong to the DWX HTML deck (relative links) — keep them beside it.

### IT-Tage deck (`docs/`)

Made with the vensas-doc-generator (`../vensas-doc-generator`), like `../playwright-2026-talk`, which is the reference for the look. Run `./generate-docs.sh` after each change to the YAML and look at the generated PDF pages.

- Write the slides in ASD-STE100 (Simplified Technical English). One idea per sentence.
- The YAML is the only source; the PDF is generated. The generator rewrites the YAML on each run (it removes comments) — edit it with a YAML parser, not with a text search.
- Put an image in a `columns` block beside the content, with an `alt`. `widths: [6, 4]` for a narrow image, `[4, 6]` for a wide one. Crop screenshots to the part that matters.
- The screenshots in `docs/img/` are real (dashboard and frontend from `aspire run`, test output from the test runs). Make them again after a visual change.
- The two customer-project slides carry the kicker `label: From a real project` on their first `heading` block and end with a `Recommendation` callout. Keep them anonymized.
- No `caption` under code listings. Put the hints in a second `columns` row with the same `widths` below the listings, so the boxes line up. Use `warning` (orange) for a caveat and `trust` (teal) beside it — both are cards with the same padding; `info` (teal, smaller) for a fact or a `Recommendation` on its own. Keep each box to one line of text.
- When you write the YAML from Ruby, do not reuse an object in two places (e.g. one `widths` array) — `to_yaml` then writes `&1`/`*1` aliases.
- No `Demo` callouts on the slides — the demo commands are in the speaker notes.
- The IT-Tage audience does not know the DWX talk. Do not tell a migration story (no "custom step → package", no "bug fixed since", no line counts of removed code). Aspire.Hosting.Testing and `Vensas.Aspire.Hosting.Kamal` are simply how the demo works.
- Watch the slide width: a code line longer than about 60 characters in a half-width column overflows.

### Services

| Component | Path | Technology | Role |
|---|---|---|---|
| `CookieJar.AppHost` | `src/CookieJar.AppHost` | Aspire AppHost | Wires all resources; publish targets |
| `CookieJar.Server` | `src/CookieJar.Server` | ASP.NET Core + EF Core | REST + SSE API, PostgreSQL, RabbitMQ consumer |
| `CookieJar.Tests` | `src/CookieJar.Tests` | xUnit v3 + Aspire.Hosting.Testing | App-model tests and E2E tests against the real AppHost |
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

SSE is powered by in-memory `Channel<int>` subscriptions in `CookieJarService` — no SignalR or external broker involved. Known limitation (kept on purpose for the talk): with 2 replicas, only the replica that consumed a RabbitMQ event notifies its own SSE clients. `LevelStream_OnEveryReplica_ReceivesEveryChange` is an `Explicit` test that demonstrates it.

### Capacity parameter

`CookieJar__Capacity` env var → bound to `CookieJarOptions.Capacity` (default 100). Injected by the AppHost:

```csharp
var capacity = builder.AddParameter("cookie-jar-capacity",
    builder.Configuration["Parameters:cookie-jar-capacity"] ?? "100", publishValueAsDefault: true);
server.WithEnvironment("CookieJar__Capacity", capacity);
```

Do NOT use `AddParameter(name, "100")` — that overload sets a constant value and ignores configuration (the DWX version had this bug; `CapacityParameter_ReadsConfiguration` guards it).

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
- `cookie-sensor` is declared after `server` on purpose: the Kamal publisher makes the first app the primary one that owns the accessories
- `AspireUseCliBundle=false` + `NoWarn ASPIRE010`: orchestration (DCP, dashboard) comes from NuGet for reproducible tests

## Tests

```sh
dotnet test src/CookieJar.Tests                                # model + E2E tests (needs Docker/Podman)
dotnet run --project src/CookieJar.Tests -- -explicit only     # known SSE-per-replica bug (fails on purpose)
```

- `AppModelTests` — builds the app model only (no containers): replicas, `WaitFor`, health check, capacity parameter
- `CookieJarAppFixture` — collection fixture that starts the AppHost once: removes PgAdmin, `frontend*` and `cookie-sensor*` resources (incl. the npm/pip installer resources Aspire 13.6 adds), removes the Postgres data volume, passes parameters as args (`Parameters:rabbitmq-password=e2e-test`, `Parameters:cookie-jar-capacity=42`), discovers per-replica URLs from `ASPNETCORE_URLS`
- `CookieJarTests` — refill uses the capacity parameter; a `cookie-taken` message published to RabbitMQ is visible on both replicas; both replicas log the migration lock (read through `ResourceLoggerService`); resets the level via SQL before each test
- Stopping/starting RabbitMQ via `ResourceCommandService` inside a test hung the run (`WaitForResourceHealthyAsync` fails right after a restart) — avoid restart-based chaos tests here

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

The server migrates at startup with `app.MigrateWithLockAsync()` (`Data/DatabaseMigrationExtensions.cs`): a PostgreSQL session advisory lock (`pg_advisory_lock`) around `MigrateAsync`, so the two replicas never migrate at the same time. It logs `Acquired the migration lock` / `Released the migration lock`; `BothReplicas_MigrateUnderTheLock` checks this. Keep the connection open between lock and unlock — the lock belongs to the session.

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
| `kamal` | `AddKamalEnvironment` ([Vensas.Aspire.Hosting.Kamal](https://github.com/vensas/aspire-hosting-kamal)) | Open-source NuGet package, not an official Aspire provider |

**Kamal** (`Vensas.Aspire.Hosting.Kamal` 0.1.1, requires Aspire ≥ 13.5.2): `AddKamalEnvironment("kamal")` with `WithServers`, `WithRegistry`, `WithProxyHostSuffix` (`<vm-ip>.nip.io`), `SshUser=ubuntu`, `BuilderArch=arm64`, `ImageNamespace=cookiejar`, proxy SSL disabled. Server IP and registry come from the `KAMAL_SERVER` / `KAMAL_REGISTRY` env vars set by `deploy/kamal/2-publish.sh`. `PublishAsKamalService` sets the proxy health check (`/health` for server, `/` for frontend). Output: `config/deploy.yml` (server + postgres/messaging accessories), `config/deploy.frontend.yml`, `config/deploy.cookie-sensor.yml`, `.kamal/secrets` (env references only), `Dockerfile.server`. `src/.dockerignore` keeps `node_modules`, `.venv`, `bin`, `obj` out of the `src` build context. The DWX custom `KamalPipelineStep` lives only at tag `dwx-2026`.

Pre-generated artifacts and numbered shell scripts live in `deploy/` — see `deploy/README.md`.

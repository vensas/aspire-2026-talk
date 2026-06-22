DO check the `docs/outline.md` file for the presentation outline and context.
DO create demo code in `src`
DO keep the `AGENTS.md` and `README.md` file up to date with the latest agent implementations and examples.
DO NOT include the content of `AGENTS.md` in the presentation outline.

## Demo project

`src/` contains the Aspire demo app (`aspire-ts-cs-starter`, Aspire SDK 13.4.6, net10.0):

- `CookieJar.AppHost` — Aspire AppHost; all resources and wiring are defined here
- `CookieJar.Server` — ASP.NET Core API; EF Core + PostgreSQL, RabbitMQ consumer, SSE endpoint
- `frontend` — React/Vite frontend
- `cookie-sensor` — Python service; publishes `cookie-taken` events to RabbitMQ

## Required setup before running

Set secrets in the AppHost project:

```sh
dotnet user-secrets set "Parameters:rabbitmq-password" "<password>" --project src/CookieJar.AppHost
```

The Python sensor's venv is at `src/cookie-sensor/.venv` and is already populated. If recreating:

```sh
cd src/cookie-sensor && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

## EF Core migrations

Migrations live in `CookieJar.Server/Migrations/`. After changing `CookieJarDbContext` or `CookieJarState`, run:

```sh
dotnet ef migrations add <Name> --project src/CookieJar.Server
```

Do NOT use dynamic values (e.g. `DateTime.UtcNow`) in `HasData` seed calls — use static hardcoded values.

## Build

```sh
dotnet build src/CookieJar.sln
```

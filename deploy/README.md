# Keksdose — Deployment

Three deployment targets, all driven by the Aspire AppHost.

> **Platform note:** Built and tested on Apple Silicon (arm64) with Podman. Registry configuration, bridge network IPs, and SSH key paths may need adjustment on other setups.

## 0. Prerequisites

- [Aspire CLI](https://aspire.dev/docs/cli): `dotnet tool install -g aspire`
- Docker (for Docker Compose and Kamal)
- Helm + kubectl (for Kubernetes)
- [Kamal](https://kamal-deploy.org/): `gem install kamal`
- [Multipass](https://multipass.run) (for local Kamal testing): `brew install --cask multipass`
- Python3

---

## 1. Docker Compose

```bash
./deploy/docker-compose/1-publish.sh   # aspire publish → deploy/output/docker-compose/
./deploy/docker-compose/2-fix.sh       # patch: RabbitMQ restart policy + healthchecks (Aspire gap)
./deploy/docker-compose/3-deploy.sh    # docker compose up
```

Aspire generates the wiring but expects pre-built images. Use a local registry for local runs.

### Local registry (first time)

```bash
# Port 5000 is used by macOS AirPlay — use 5001
docker run -d -p 5001:5000 --name local-registry --restart=always registry:2
```

**Podman: allow insecure access to the local registry**

Add to `~/.config/containers/registries.conf`:

```toml
[[registry]]
location = "localhost:5001"
insecure = true
```

The compose engine runs inside the Podman VM, so it needs the same:

```bash
podman machine ssh "sudo tee -a /etc/containers/registries.conf << 'EOF'

[[registry]]
location = \"localhost:5001\"
insecure = true
EOF"
podman machine ssh "sudo systemctl restart podman.socket"
```

If `~/.docker/config.json` has `"credsStore": "desktop"`, remove it — `docker-credential-desktop` is not present in a Podman setup and will break `docker compose pull`.

### Build and push images

```bash
dotnet publish src/CookieJar.Server/CookieJar.Server.csproj \
  /t:PublishContainer \
  -p ContainerRegistry=localhost:5001 \
  -p ContainerImageName=cookiejar-server \
  -p ContainerImageTag=latest

docker build \
  -f deploy/output/docker-compose/cookie-sensor.Dockerfile \
  -t localhost:5001/cookiejar-cookie-sensor:latest \
  src/cookie-sensor
docker push localhost:5001/cookiejar-cookie-sensor:latest

docker build -t localhost:5001/cookiejar-frontend:latest src/frontend
docker push localhost:5001/cookiejar-frontend:latest
```

### .env

`1-publish.sh` copies `deploy/.env.template` into the output directory after each publish. Edit `deploy/.env.template` to change registry, passwords, or ports.

---

## 2. Kubernetes / Helm

```bash
./deploy/kubernetes/1-publish.sh   # aspire publish → deploy/output/helm/
./deploy/kubernetes/2-fix.sh       # patch: volume name dots + liveness/readiness probes (Aspire gaps)
./deploy/kubernetes/3-build.sh     # build images and load into minikube
./deploy/kubernetes/4-deploy.sh    # helm upgrade --install
./deploy/kubernetes/5-forward.sh   # kubectl port-forward → localhost:8080
```

The Aspire Kubernetes provider is a **Preview** feature. The generated Helm chart is a starting point — `2-fix.sh` patches two known gaps: volume names with dots are invalid in Kubernetes, and the provider does not yet emit liveness/readiness probes from `WithHttpHealthCheck`.

---

## 3. Kamal (Vensas.Aspire.Hosting.Kamal)

Kamal deploys Docker containers directly to VMs via SSH — no Kubernetes required. The AppHost uses the open-source [Vensas.Aspire.Hosting.Kamal](https://github.com/vensas/aspire-hosting-kamal) package (`AddKamalEnvironment`), which generates one Kamal config per app:

| File | Content |
|---|---|
| `config/deploy.yml` | `server` (primary app) + `postgres` and `messaging` accessories |
| `config/deploy.frontend.yml` | nginx frontend, proxies `/api/` to `http://server-web:8080` |
| `config/deploy.cookie-sensor.yml` | Python sensor, no proxy |
| `.kamal/secrets` | Only references to env vars (`$POSTGRES_PASSWORD`, `$RABBITMQ_PASSWORD`, `$KAMAL_REGISTRY_PASSWORD`) |
| `Dockerfile.server` | Generated multi-stage .NET build (context: `src/`) |

### Testing locally with Multipass

```bash
./deploy/kamal/1-setup-vm.sh     # launch VM, start local registry, install SSH key
./deploy/kamal/2-publish.sh      # aspire publish with the VM IP and registry baked into the configs
./deploy/kamal/3-build-push.sh   # build the generated Dockerfiles with Podman + push
./deploy/kamal/4-setup.sh        # first time: install Docker, boot proxy + accessories (~2 min)
./deploy/kamal/5-deploy.sh       # kamal deploy --skip-push for each app config
```

`_common.sh` holds the shared settings and demo secret defaults (`POSTGRES_PASSWORD`, `RABBITMQ_PASSWORD`, `KAMAL_REGISTRY_PASSWORD` — override them via the environment) and adds `~/.ssh/kamal-multipass` to the ssh-agent.

Kamal can build images itself, but needs `docker buildx`. This setup uses Podman, so `3-build-push.sh` builds the images from the generated configs, and `5-deploy.sh` deploys with `--skip-push --version <git sha>`. With Docker, `aspire deploy` can run `kamal deploy` directly.

After a successful deploy (hostnames via [nip.io](https://nip.io), SSL disabled for the local VM):

| Service | URL |
|---|---|
| Frontend | `http://frontend.<VM_IP>.nip.io` |
| API | `http://server.<VM_IP>.nip.io/scalar` |
| Health | `http://server.<VM_IP>.nip.io/health` |

**Teardown:**

```bash
./deploy/kamal/6-teardown.sh     # kamal remove per app, optionally destroy VM and local registry
```

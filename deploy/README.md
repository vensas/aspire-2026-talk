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

## 3. Kamal (Custom Pipeline Step)

Kamal deploys Docker containers directly to VMs via SSH — no Kubernetes required.

```bash
./deploy/kamal/2-publish.sh      # aspire publish via custom KamalPipelineStep
# fill in deploy/output/kamal/.kamal/secrets
./deploy/kamal/3-build-push.sh   # build + push all images
./deploy/kamal/4-setup.sh        # first time: install Docker, boot proxy + accessories
./deploy/kamal/5-deploy.sh       # deploy (subsequent runs skip 4-setup.sh)
```

The Kamal integration is **experimental** — `KamalDeploymentResource` is a custom `PipelineStep` that walks the Aspire resource model and generates `config/deploy.yml` + `.kamal/secrets.example`. It is not an official Aspire provider.

After a successful deploy:

| Service | URL |
|---|---|
| API | `http://<SERVER_IP>` |
| Frontend | `http://<SERVER_IP>:3000` |
| Health | `http://<SERVER_IP>/health` |

### Testing locally with Multipass

```bash
./deploy/kamal/1-setup-vm.sh     # launch VM, start local registry, install SSH key

./deploy/kamal/2-publish.sh
# edit deploy/output/kamal/.kamal/secrets (IPs are printed by 1-setup-vm.sh)

./deploy/kamal/3-build-push.sh
./deploy/kamal/4-setup.sh        # ~2 min first time
./deploy/kamal/5-deploy.sh
```

**Teardown:**

```bash
./deploy/kamal/6-teardown.sh     # undeploy, optionally destroy VM and local registry
```

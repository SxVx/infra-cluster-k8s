# Operations runbook

## Prerequisites

`terraform` ≥ 1.5, `kubectl`, `helm` ≥ 3, a Rackspace Spot account and a domain managed by Cloudflare.

Local secrets, outside the repo ([ADR-0005](decisions/0005-secrets-out-of-git.md)):

```bash
mkdir -p ~/.config/rackspace && chmod 700 ~/.config/rackspace
read -rs "?Spot token: " t   # zsh; in bash: read -rsp "Spot token: " t
printf 'TF_VAR_rackspace_spot_token=%s\n' "$t" > ~/.config/rackspace/spot.env && unset t
chmod 600 ~/.config/rackspace/spot.env
```

Keep the Spot kubeconfig separate from other clusters:

```bash
# ~/.zshrc
export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/spot-portafolio.yaml"
alias spot-kubeconfig="$HOME/path/to/infra/scripts/spot-kubeconfig.sh"
```

## Bootstrap from zero

### 1. Cluster

```bash
cd terraform/spot-cluster
cp terraform.tfvars.example terraform.tfvars
set -a; source ~/.config/rackspace/spot.env; set +a
terraform init && terraform apply     # ~10–20 min until the node is Ready
cd ../.. && scripts/spot-kubeconfig.sh
kubectl get nodes
```

### 2. Gateway API CRDs + Traefik

The Traefik chart no longer ships the Gateway API CRDs ([ADR-0007](decisions/0007-gateway-api.md)).
Install them first, pinned to the version the chart documents:

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

```bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
# Always render first: a misplaced value is ignored without an error.
helm template traefik traefik/traefik --version 41.6.0 -n traefik \
  -f k8s/traefik/values.yaml -s templates/service.yaml | grep 'type:'   # → ClusterIP
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --version 41.6.0 -f k8s/traefik/values.yaml
```

### 3. Cloudflare Tunnel

1. Cloudflare Zero Trust → Networks → Tunnels → **Create a tunnel** (type *Cloudflared*). Copy the token
   but do not install anything from that screen.
2. Store the token in the cluster:
   ```bash
   kubectl create namespace cloudflared
   kubectl -n cloudflared create secret generic cloudflared-token --from-literal=token='<TOKEN>'
   kubectl apply -k k8s/cloudflared
   ```
3. In the tunnel's *Published application routes*: subdomain `*`, domain `jesevilla.dev`,
   service `HTTP` → `traefik.traefik.svc.cluster.local:80`.
4. DNS: add a proxied `CNAME *` → `<tunnel-id>.cfargotunnel.com`.

### 4. Gateway, routes and smoke test

```bash
kubectl apply -k k8s/whoami
kubectl apply -k k8s/gateway
kubectl -n traefik get gateway public               # PROGRAMMED=True
kubectl -n traefik get httproute                    # check status if a host returns 404
curl -I https://whoami.jesevilla.dev                # HTTP/2 200
```

## Publishing a new app

All public hostnames live in [`k8s/gateway/routes.yaml`](../k8s/gateway/routes.yaml) ([ADR-0007](decisions/0007-gateway-api.md)).
No Cloudflare change is needed for `<app>.jesevilla.dev`.

1. Create `k8s/<app>/` with one file per resource (`namespace.yaml`, `deployment.yaml`, `service.yaml`,
   `referencegrant.yaml`) and a `kustomization.yaml` listing them. Copy `k8s/whoami/` as a template.
2. Add an HTTPRoute to `k8s/gateway/routes.yaml` (namespace `traefik`, `parentRefs: [{name: public}]`,
   `backendRefs` with the app `namespace`).
3. Apply both:
   ```bash
   kubectl apply -k k8s/<app>
   kubectl apply -k k8s/gateway
   kubectl -n traefik describe httproute <app>      # Accepted=True, ResolvedRefs=True
   ```

`ResolvedRefs=False` with reason `RefNotPermitted` means the ReferenceGrant is missing or names another Service.
Always set `resources.requests` and `limits`: the cluster has a single node.

### App deployed from its own repo (CI/CD)

Example: `k8s/personal-web/` (portfolio, repo `SxVx/personal-web-page`). Besides the usual files it has
`rbac.yaml`: a `ci-deployer` ServiceAccount restricted to that namespace. The app pipeline only runs
`kubectl set image` + `rollout status`.

```bash
kubectl apply -k k8s/personal-web
scripts/ci-kubeconfig.sh personal-web | pbcopy   # → app repo: secret KUBE_CONFIG
```

Re-run `scripts/ci-kubeconfig.sh` after every `terraform destroy/apply` (the API endpoint changes).

## One-time migration from Ingress to Gateway API

Order matters: CRDs, ReferenceGrants and routes go in before Traefik switches providers, so the cutover
is a single Traefik restart.

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl apply -k k8s/whoami && kubectl apply -k k8s/personal-web     # adds the ReferenceGrants
kubectl apply -k k8s/gateway        # idle until Traefik enables the Gateway provider
helm upgrade traefik traefik/traefik -n traefik --version 41.6.0 -f k8s/traefik/values.yaml
kubectl -n traefik get gateway,httproute
curl -I https://whoami.jesevilla.dev
kubectl delete ingress -A --all                                       # leftovers, now unused
```

## Routine checks

```bash
kubectl get svc -A | grep LoadBalancer      # must be empty (each LB costs ~$10/month)
kubectl get nodes                           # node Ready; a new node name means a preemption happened
kubectl -n cloudflared get pods             # 2/2 Running
```

Review the Spot cost explorer monthly.

## Upgrades

| Component | How |
|---|---|
| Traefik | Bump `--version`, read the chart changelog, `helm template`, then `helm upgrade` |
| cloudflared / whoami | Change the image tag, `kubectl diff -k`, `kubectl apply -k`, `kubectl rollout status` |
| Kubernetes | Change `kubernetes_version`, then `terraform plan` / `apply` |
| Gateway API CRDs | Check the version the Traefik chart supports, then `kubectl apply --server-side -f .../<version>/standard-install.yaml` |

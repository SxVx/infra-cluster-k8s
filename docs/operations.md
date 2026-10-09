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

### 2. Traefik

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
   kubectl apply -f k8s/cloudflared/cloudflared.yaml
   ```
3. In the tunnel's *Published application routes*: subdomain `*`, domain `jesevilla.dev`,
   service `HTTP` → `traefik.traefik.svc.cluster.local:80`.
4. DNS: add a proxied `CNAME *` → `<tunnel-id>.cfargotunnel.com`.

### 4. Smoke test

```bash
kubectl apply -f k8s/whoami/whoami.yaml
curl -I https://whoami.jesevilla.dev        # HTTP/2 200
```

## Publishing a new app

Create a namespace, Deployment and Service, plus an Ingress **in the same namespace** as the Service.
No Cloudflare change is needed:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.jesevilla.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

Always set `resources.requests` and `limits`: the cluster has a single node.

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
| cloudflared / whoami | Change the image tag, `kubectl diff -f`, `kubectl apply -f`, `kubectl rollout status` |
| Kubernetes | Change `kubernetes_version`, then `terraform plan` / `apply` |

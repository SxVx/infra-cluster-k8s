# Change record: migration from Ingress to the Gateway API

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Decision** | [ADR-0007](../decisions/0007-gateway-api.md) |
| **Commit** | `6634063` — manifests, Helm values, CI and docs |
| **Downtime** | None observed (`whoami` answered 200 before and after the Traefik restart) |
| **Result** | Successful. Traefik routes only through the Gateway API; no Ingress or IngressClass remains |

## Goal

One tunnel, one entry point and one place listing every public hostname. With the `Ingress` API that was not
possible: an Ingress can only reference Services in its own namespace, so each app needed its own.

## Before / after

| | Before | After |
|---|---|---|
| Routing API | `Ingress` (one per namespace) | Gateway API: Gateway `traefik/public` + HTTPRoutes in `k8s/gateway/routes.yaml` |
| Traefik providers | `kubernetesIngress` | `kubernetesGateway` (Ingress provider and IngressClass disabled) |
| Cross-namespace access | n/a | One ReferenceGrant per app namespace, scoped to one Service |
| Manifests | One multi-document YAML per app | One file per resource + `kustomization.yaml`, applied with `kubectl apply -k` |
| Gateway API CRDs | Not installed | v1.6.1 standard channel, installed outside the Helm chart |
| Cloudflare Tunnel / DNS | `*.jesevilla.dev` → `traefik.traefik.svc:80` | Unchanged |

## Pre-checks

| Check | Command | Result |
|---|---|---|
| Values already in the release | `helm get values traefik -n traefik` | Only `service.spec.type: ClusterIP`, already in `values.yaml`: nothing lost by `-f` without `--reuse-values` |
| Rendered chart | `helm template traefik traefik/traefik --version 41.6.0 -n traefik -f k8s/traefik/values.yaml \| grep -E 'type: (ClusterIP\|LoadBalancer)\|kubernetesgateway\|kubernetesingress\|kind: (GatewayClass\|IngressClass)'` | `ClusterIP`, `--providers.kubernetesgateway`, `GatewayClass`; no `kubernetesingress`, no `IngressClass` |
| Existing Gateway API CRDs | `kubectl get crd \| grep gateway.networking.k8s.io` | None, clean install |
| Existing Ingress objects | `kubectl get ingress -A` | Only `whoami/whoami` |

Offline validation (before touching the cluster): every `k8s/*/kustomization.yaml` rendered and validated with
kubeconform 0.8.0 (including Gateway API schemas), and `values.yaml` validated against the chart's
`values.schema.json`.

## Commands applied

Run from the repo root, in this order. Routes and grants go in **before** Traefik switches providers, so the
cutover is a single Traefik restart.

```bash
# 1. Gateway API CRDs (the Traefik chart no longer ships them)
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl get crd | grep gateway.networking.k8s.io
#   backendtlspolicies, gatewayclasses, gateways, grpcroutes, httproutes, listenersets,
#   referencegrants, tcproutes, tlsroutes, udproutes (+ ValidatingAdmissionPolicy safe-upgrades)

# 2. Apps with their ReferenceGrants (no traffic change yet)
kubectl apply -k k8s/whoami
#   referencegrant/allow-gateway-routes created; deployment configured (manifest split only)
kubectl apply -k k8s/personal-web
#   namespace, ServiceAccount/Role/RoleBinding/Secret ci-deployer, Service, Deployment, ReferenceGrant created

# 3. Gateway and routes (idle until Traefik enables the provider)
kubectl apply -k k8s/gateway
#   gateway/public, httproute/personal-web, httproute/whoami created

# 4. Switch Traefik to the Gateway API (REVISION 3)
helm upgrade traefik traefik/traefik -n traefik --version 41.6.0 -f k8s/traefik/values.yaml
kubectl -n traefik rollout status deployment/traefik

# 5. Verification
kubectl -n traefik get gateway public                 # PROGRAMMED=True
kubectl -n traefik get httproute                      # personal-web, whoami
kubectl -n traefik describe httproute whoami          # Accepted=True, ResolvedRefs=True
curl -I https://whoami.jesevilla.dev                  # HTTP/2 200

# 6. Cleanup
kubectl delete ingress -n whoami whoami
kubectl get ingressclass                              # No resources found
curl -I https://whoami.jesevilla.dev                  # HTTP/2 200
```

## Notes

- `helm upgrade` prints *"DEPRECATION WARNING: Gateway API CRDs will no longer be shipped with this chart…"*.
  It is a static message in the chart's `NOTES.txt`, shown whenever `providers.kubernetesGateway.enabled` is
  true; it does not inspect the cluster. The chart already stopped shipping the CRDs in 40.2.0, and the
  message still mentions v1.5.1 while the chart README recommends v1.6.1. No action needed.
- Rollback path, valid until the old Ingress was deleted: `helm rollback traefik -n traefik`. From now on a
  rollback also needs the Ingress manifests from git history (`git show 6634063^:k8s/whoami/whoami.yaml`).

## Follow-ups

- [ ] `personal-web`: stays in `ImagePullBackOff` until the app pipeline publishes the image and the GHCR
      package is made public.
- [ ] `personal-web` Deployment: review `limits.cpu: 10m` (throttling), `ephemeral-storage: 2000Mi` request
      (reserves node disk) and probes on `/` (302 + access-log noise; `/healthz` is meant for this).
- [ ] Cloudflare Tunnel route for the apex `jesevilla.dev` (the `*` wildcard only covers `www`).
- [ ] App repo secret `KUBE_CONFIG`: `scripts/ci-kubeconfig.sh personal-web`.

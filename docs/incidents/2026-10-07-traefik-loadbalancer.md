# Postmortem: Traefik exposed through an unintended cloud load balancer

| | |
|---|---|
| **Date resolved** | 2026-10-07 |
| **Duration** | 13 days (since Traefik was installed on 2026-09-24) |
| **Severity** | Low: cost and security exposure, no downtime |
| **Detected by** | A load balancer line item on the monthly Spot invoice |

## Summary

Traefik was meant to run as a `ClusterIP` Service behind the Cloudflare Tunnel
([ADR-0002](../decisions/0002-cloudflare-tunnel.md)). Instead, the Helm chart created a `LoadBalancer`
Service. Spot provisioned a cloud load balancer with a public IP. That added ~$3.70 to the bill, roughly
70% of the total, and let anyone reach Traefik directly, **bypassing Cloudflare** (TLS, proxy and any future
Access policies).

## Root cause

Traefik was installed with `--set service.type=ClusterIP`. In chart **41.x** the Service type lives under
`service.spec.type`. The old key is not part of the template, so Helm accepted it without any error or
warning, and the chart rendered its default, `LoadBalancer`. Spot's `cloud-controller-manager` then did
exactly what it should: it provisioned a load balancer for the Service.

## Investigation

| Step | Command | Finding |
|---|---|---|
| 1 | `kubectl get svc -A \| grep LoadBalancer` | `traefik` was `LoadBalancer` with a public IP |
| 2 | `helm get values traefik -n traefik` | The supplied value was `service.type: ClusterIP`, so the intent was correct |
| 3 | `helm get manifest traefik -n traefik` | The rendered manifest was `type: LoadBalancer`, so the chart ignored the value |
| 4 | `kubectl get svc traefik -o yaml --show-managed-fields` | Managers were only `helm` and `cloud-controller-manager`, which ruled out a manual edit |
| 5 | `helm show values traefik/traefik --version 41.6.0` | The correct key is `service.spec.type` |

## Resolution

1. Wrote [`k8s/traefik/values.yaml`](../../k8s/traefik/values.yaml) with `service.spec.type: ClusterIP`.
2. Validated without touching the cluster:
   `helm template … -s templates/service.yaml | grep type:` → `ClusterIP`.
3. `helm upgrade traefik traefik/traefik -n traefik --version 41.6.0 -f k8s/traefik/values.yaml`
4. Verified:
   - the Service is `ClusterIP` with no external IP;
   - `https://whoami.jesevilla.dev` still answers through the tunnel;
   - the former public IP times out;
   - the load balancer is gone from the Spot console.

## Lessons and follow-ups

- **Render before you apply.** `helm template` is now mandatory before any install or upgrade. Helm does not
  validate unknown keys unless the chart ships a strict schema.
- **Values belong in Git, not in `--set`.** A values file can be reviewed, diffed and reused.
- **Pin chart versions** and keep the chart version (`41.6.0`) distinct from the app version (`v3.7.13`).
- **Watch for the expensive default.** After every install, run `kubectl get svc -A | grep LoadBalancer`.
  A policy (e.g. Kyverno) that denies `LoadBalancer` Services is a candidate once Argo CD is in place.

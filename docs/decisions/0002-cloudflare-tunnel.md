# ADR-0002: Cloudflare Tunnel instead of a cloud load balancer

**Status:** Accepted · **Date:** 2026-09

## Context

Exposing HTTP services normally means a `LoadBalancer` Service. On Spot that costs ~$10/month, more than
the compute itself, and it gives the cluster a public IP that anyone can reach directly.

## Decision

Run `cloudflared` inside the cluster (2 replicas) and publish everything through a **Cloudflare Tunnel**:

- Tunnel route: `*.jesevilla.dev` → `http://traefik.traefik.svc.cluster.local:80`
- DNS: a proxied wildcard `CNAME *` pointing to the tunnel. Cloudflare does not create it automatically for
  wildcards.
- Traefik stays a `ClusterIP` Service.

## Consequences

- ✅ $0 for ingress. The cluster has **no inbound ports and no public IP**, and Cloudflare provides TLS and
  proxying in front of it.
- ✅ Publishing a new subdomain only needs a new Ingress object. DNS and the tunnel stay untouched.
- ✅ Admin tools can be protected later with Cloudflare Access (free up to 50 users).
- ⚠️ Everything under `*.jesevilla.dev` is public as soon as an Ingress exists. Internal tools must sit
  behind Access.
- ⚠️ Vendor lock-in on Cloudflare for the edge, and the wildcard covers a single level (`app.jesevilla.dev`),
  not the root domain.
- ⚠️ Any chart that defaults to `LoadBalancer` silently brings the cost and the exposure back. This happened
  once: see the [incident](../incidents/2026-10-07-traefik-loadbalancer.md).

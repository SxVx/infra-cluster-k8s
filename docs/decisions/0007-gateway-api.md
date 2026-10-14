# ADR-0007: Gateway API with a single Gateway and centralized routes

**Status:** Accepted · **Date:** 2026-10 · Supersedes the routing part of [ADR-0003](0003-traefik-ingress.md)

## Context

The cluster has one tunnel and one Traefik, but routing was spread over one `Ingress` per namespace: an
`Ingress` can only point to Services in its own namespace, so a single cluster-wide `Ingress` is not possible.
The `Ingress` API is also feature-frozen; the Gateway API is its successor and Traefik implements it.

## Decision

- Install the Gateway API CRDs (standard channel, pinned) and enable Traefik's `kubernetesGateway` provider.
  The `kubernetesIngress` provider and the IngressClass are disabled.
- **One Gateway** (`traefik/public`, [`k8s/gateway/gateway.yaml`](../../k8s/gateway/gateway.yaml)) with
  `allowedRoutes.namespaces.from: Same`: only routes in the `traefik` namespace can attach to it.
- **All HTTPRoutes in one file**, [`k8s/gateway/routes.yaml`](../../k8s/gateway/routes.yaml), in the
  `traefik` namespace, pointing to Services in the app namespaces.
- Each app namespace grants that access with a **ReferenceGrant** scoped to a single Service.

## Consequences

- ✅ One place lists every public hostname of the cluster. A route cannot be published from an app namespace.
- ✅ Standard, actively developed API; no controller-specific annotations.
- ⚠️ Each app still needs one object in its namespace (the ReferenceGrant). Without it the route is
  rejected with `RefNotPermitted`, which shows up only in the HTTPRoute status, not on apply.
- ⚠️ Cross-namespace references have had vulnerabilities (CVE-2026-54761, fixed in Traefik 3.7.5).
  Keep Traefik patched and keep ReferenceGrants scoped to a named Service.
- ⚠️ The Traefik chart no longer ships the Gateway API CRDs: they are installed and upgraded separately,
  and must be in place before Traefik starts with the provider enabled.
- Alternative not chosen: one HTTPRoute per app namespace attached to the shared Gateway. It needs no
  ReferenceGrants, but the list of public hostnames is spread across the repo.

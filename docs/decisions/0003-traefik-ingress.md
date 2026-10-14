# ADR-0003: Traefik as the ingress controller

**Status:** Accepted · **Date:** 2026-09 · Routing API superseded by [ADR-0007](0007-gateway-api.md) (Traefik stays)

## Context

The tunnel forwards every hostname to a single internal endpoint, so something in the cluster has to route
requests by `Host` header. ingress-nginx, the usual default, has been retired by the Kubernetes project
and no longer receives maintenance.

## Decision

Install Traefik with its official Helm chart, with the version pinned and the values kept in
[`k8s/traefik/values.yaml`](../../k8s/traefik/values.yaml).

## Consequences

- ✅ Actively maintained, and it supports the standard `Ingress` API, so app manifests stay portable.
- ✅ One Traefik serves Ingress objects from every namespace; each project only adds its own Ingress.
- ⚠️ Chart values change between major versions, and a misplaced key is ignored without an error. Every
  install or upgrade is validated first with `helm template`.

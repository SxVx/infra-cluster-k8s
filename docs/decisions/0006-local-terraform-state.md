# ADR-0006: Local Terraform state, for now

**Status:** Accepted (to revisit) · **Date:** 2026-09

## Context

Terraform state is the only link between the code and the real cloudspace, and it contains the kubeconfig
token. A remote backend adds setup work and one more credential.

## Decision

Keep the state local and git-ignored while a single person operates the platform from one machine.

## Consequences

- ✅ Zero setup and zero cost.
- ⚠️ Losing the laptop means losing the state. The cloudspace would then have to be imported or recreated.
  It needs to be backed up manually.
- ⚠️ No locking, which is fine for one operator but not for CI-driven applies.

**Next step:** move the state to Cloudflare R2. Its S3-compatible API works with Terraform's `s3` backend,
and the free tier covers this usage.

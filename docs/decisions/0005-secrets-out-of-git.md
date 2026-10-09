# ADR-0005: Secrets created out-of-band, never in Git

**Status:** Accepted · **Date:** 2026-10

## Context

The platform has two secrets: the Rackspace Spot API token, used by Terraform, and the Cloudflare Tunnel
token, used by `cloudflared`. The repository is public, a single person operates the cluster, and both tokens
can be rotated in minutes.

## Decision

- No secret is ever committed. `.gitignore` excludes state, `tfvars`, kubeconfigs and `.env` files, and CI
  runs secret scanning on every push.
- The tunnel token is created directly in the cluster:
  `kubectl -n cloudflared create secret generic cloudflared-token --from-literal=token=...`
- The Spot token lives in a local file outside the repo (`~/.config/rackspace/spot.env`, mode `600`) and is
  loaded only into the Terraform process by [`scripts/spot-kubeconfig.sh`](../../scripts/spot-kubeconfig.sh).
- If a leak is suspected, the token is rotated.

## Alternatives considered

| Option | Why not (yet) |
|---|---|
| SOPS + age | The best fit once Argo CD manages secrets from Git; unnecessary overhead with manual deploys. |
| Sealed Secrets | The private key lives in the cluster, so recreating the cluster without a backup makes every secret undecryptable. |
| Password-manager CLI | One more dependency and an unlock step for two tokens. |

## Consequences

- ✅ Simple, and nothing sensitive can reach the public repository through normal work.
- ⚠️ Secrets are not reproducible from Git, so a rebuilt cluster needs the manual `create secret` step
  (documented in [operations](../operations.md)).
- ⚠️ The local token file is plain text. This is an accepted risk, mitigated by file permissions and rotation.

# Architecture Decision Records

Short records of the decisions behind this platform: the context, what was chosen, and what it costs.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-rackspace-spot.md) | Rackspace Spot as the compute provider | Accepted |
| [0002](0002-cloudflare-tunnel.md) | Cloudflare Tunnel instead of a cloud load balancer | Accepted |
| [0003](0003-traefik-ingress.md) | Traefik as the ingress controller | Accepted |
| [0004](0004-single-node.md) | A single memory-heavy Gen 1 node | Accepted |
| [0005](0005-secrets-out-of-git.md) | Secrets created out-of-band, never in Git | Accepted |
| [0006](0006-local-terraform-state.md) | Local Terraform state, for now | Accepted (to revisit) |

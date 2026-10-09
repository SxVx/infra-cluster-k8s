# ADR-0001: Rackspace Spot as the compute provider

**Status:** Accepted · **Date:** 2026-09

## Context

I need a real Kubernetes cluster for personal projects and a DevOps portfolio, with low traffic and a budget
of **$7–10 USD/month**. Managed offerings from the big clouds charge for the control plane or need several
always-on nodes, which puts them well above that budget.

## Decision

Use [Rackspace Spot](https://spot.rackspace.com): managed Kubernetes where worker nodes are rented through an
auction.

## Consequences

- ✅ The non-HA control plane is free, and nodes are billed at the market price, not at my bid. The real cost
  has been ~$0.005/h for a 4 vCPU / 32 GB node.
- ✅ Ingress traffic is free, and there is an official Terraform provider (`rackerlabs/spot`).
- ⚠️ Nodes can be **preempted** when the market price exceeds the bid. See [ADR-0004](0004-single-node.md).
- ⚠️ A smaller ecosystem than the hyperscalers, so problems such as a failed CNI addon during creation
  (see [troubleshooting](../troubleshooting.md)) have to be debugged without much community help.
- ⚠️ Spot's own `LoadBalancer` costs ~$10/month, which led to [ADR-0002](0002-cloudflare-tunnel.md).

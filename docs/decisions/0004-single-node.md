# ADR-0004: A single memory-heavy Gen 1 node

**Status:** Accepted · **Date:** 2026-09

## Context

Spot prices each server class independently. At the time of the decision, the Gen 1 memory-heavy class
`mh.vs1.large-dfw` (4 vCPU, 32 GB) cleared at about the same market price as much smaller Gen 2 classes
(~4 GB), and the Dallas region is the closest to my users in Mexico.

## Decision

Run **one** `mh.vs1.large-dfw` node with a bid ceiling of `$0.02/h`. The class minimum is `0.015`, and bids
are rounded down to steps of `0.005`.

## Consequences

- ✅ 8× the memory for the same price, enough to run Argo CD, observability and several apps.
- ✅ The bid ceiling caps the worst case at ~$14.40/month.
- ⚠️ **No redundancy.** If the node is preempted, every app is down until a replacement joins. That is
  acceptable for a portfolio, and the mitigations are:
  - `requests`/`limits` on every workload, so one app cannot starve the rest;
  - no important data stored only in the cluster;
  - preemption alerts via `preemption_webhook` (roadmap).
- ⚠️ Older CPUs: images built for `x86-64-v3` may fail to start on Gen 1 hardware.

# Troubleshooting log

Problems hit while building the platform, with their cause and fix.

| Symptom | Cause | Fix |
|---|---|---|
| `bid price 0.01 is below the minimum bid price of 0.015` | Class minimum for `mh.vs1.large-dfw`. Spot also **rounds bids down** to steps of 0.005, so `0.013` became `0.01`. | Bid `0.02`. A Terraform `validation` now rejects non-multiples of 0.005. |
| Cloudspace stuck in `CreateClusterFailed`, node `NotReady`, empty `tigerastatus` | The Calico addon failed to install during creation (`proxy-addons … the object has been modified`). | `terraform destroy` + `apply`. The second attempt was slower but succeeded. |
| `Cloudspace is not ready … Provisioning phase` | Terraform stopped waiting before Spot finished provisioning. | Wait, then run `terraform apply` again (no changes to add). |
| `kubectl`: `no such host` | The kubeconfig still pointed to a destroyed cloudspace's endpoint. | Regenerate it with `scripts/spot-kubeconfig.sh`. |
| `kubectl`: `the server has asked for the client to provide credentials` (401) | The kubeconfig token is short-lived, and `terraform output` returns the **stored** one. | `terraform apply -refresh-only` before reading the output. The script does this. |
| Wildcard hostname not resolving through the tunnel | Cloudflare does not create DNS records for `*` tunnel routes. | Create a proxied `CNAME *` → `<tunnel-id>.cfargotunnel.com` manually. |
| Unexpected load balancer charge | The Traefik chart ignored `service.type`. | See the [postmortem](incidents/2026-10-07-traefik-loadbalancer.md). |
| `helm upgrade --version 3.7.13`: chart not found | `--version` expects the **chart** version (`41.6.0`), not the app version. | Read the `CHART` column of `helm list`. |

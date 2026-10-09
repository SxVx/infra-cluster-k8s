# terraform/spot-cluster

Provisions a Rackspace Spot cloudspace (managed Kubernetes control plane) and a Spot node pool.

| Resource | Purpose |
|---|---|
| `spot_cloudspace.this` | Cluster: region, Kubernetes version, Calico CNI, non-HA control plane (free) |
| `spot_spotnodepool.workers` | Auction-priced worker nodes |
| `data.spot_kubeconfig.this` | Kubeconfig with a short-lived token, exposed as the `kubeconfig` output |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_rackspace_spot_token=...   # from the Spot UI → API access
terraform init
terraform plan
terraform apply
```

Then generate the kubeconfig with [`scripts/spot-kubeconfig.sh`](../../scripts/spot-kubeconfig.sh).

## Notes

- **State is local** and contains the kubeconfig token. It is git-ignored; back it up. Moving it to
  Cloudflare R2 is on the roadmap ([ADR-0006](../../docs/decisions/0006-local-terraform-state.md)).
- **Bids are rounded down to steps of 0.005.** A `validation` block rejects other values, because
  `0.013` would silently become `0.01` and fail the class minimum.
- **Do not change Terraform-managed settings in the Spot UI** (bid, node count): the next `apply` reverts them.
- After a `destroy` + `apply` the API endpoint changes; regenerate the kubeconfig.

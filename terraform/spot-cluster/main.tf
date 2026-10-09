resource "spot_cloudspace" "this" {
  cloudspace_name    = var.cloudspace_name
  region             = var.region
  hacontrol_plane    = false
  cni                = "calico"
  kubernetes_version = var.kubernetes_version
  preemption_webhook = var.preemption_webhook
  wait_until_ready   = true
}

resource "spot_spotnodepool" "workers" {
  cloudspace_name      = spot_cloudspace.this.cloudspace_name
  server_class         = var.server_class
  bid_price            = var.bid_price
  desired_server_count = var.node_count
}

# The kubeconfig token is short-lived: refresh it with `terraform apply -refresh-only`
# (scripts/spot-kubeconfig.sh does this).
data "spot_kubeconfig" "this" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name
  depends_on      = [spot_spotnodepool.workers]
}

output "kubeconfig" {
  description = "Kubeconfig for the cloudspace. Contains a short-lived token."
  value       = data.spot_kubeconfig.this.raw
  sensitive   = true
}

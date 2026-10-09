variable "rackspace_spot_token" {
  description = "Rackspace Spot API token. Pass it as TF_VAR_rackspace_spot_token, never in a tfvars file."
  type        = string
  sensitive   = true
}

variable "cloudspace_name" {
  description = "Name of the cloudspace (cluster)."
  type        = string
}

variable "region" {
  description = "Spot region, e.g. us-central-dfw-1."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version offered by Spot for the cloudspace."
  type        = string
  default     = "1.34.9"
}

variable "server_class" {
  description = "Server class for the node pool, e.g. mh.vs1.large-dfw. Check availability and market price in the Spot UI."
  type        = string
}

variable "bid_price" {
  description = "Maximum bid in USD per hour per node. You pay the market price, up to this ceiling."
  type        = number

  validation {
    # Spot rounds bids down to steps of 0.005; anything else silently becomes a lower bid.
    condition     = var.bid_price > 0 && floor(var.bid_price * 1000 + 0.5) % 5 == 0
    error_message = "bid_price must be a positive multiple of 0.005 (e.g. 0.015, 0.02)."
  }
}

variable "node_count" {
  description = "Number of Spot nodes in the pool."
  type        = number
  default     = 1
}

variable "preemption_webhook" {
  description = "Optional webhook URL (e.g. Slack) notified before a node is preempted."
  type        = string
  default     = null
}

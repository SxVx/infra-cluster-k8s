terraform {
  required_version = ">= 1.5"

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = "~> 0.1.4"
    }
  }
}

provider "spot" {
  token = var.rackspace_spot_token
}

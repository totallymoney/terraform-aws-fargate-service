data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_vpc" "this" {
  id = var.vpc_id
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region
  vpc_cidr   = data.aws_vpc.this.cidr_block

  tags = merge(var.tags, { ManagedBy = "terraform" })

  # Suffix keeps the globally unique access log bucket name collision free
  # without putting the account id in it.
  suffix = substr(sha256("${local.account_id}-${var.name}"), 0, 8)
}

# Warnings, not errors, so you can still ship a staging environment that is
# deliberately open. Read them.
check "alb_not_open_to_the_world" {
  assert {
    condition     = !contains(var.alb_ingress_cidrs, "0.0.0.0/0")
    error_message = "alb_ingress_cidrs contains 0.0.0.0/0. If a CDN is meant to be in front of this, the origin is now reachable directly and the CDN's protections can be bypassed."
  }
}

check "image_is_pinned" {
  assert {
    condition     = !endswith(var.container_image, ":latest")
    error_message = "container_image ends in :latest. Deployments will not be reproducible and a rollback may not get you the bytes you rolled back to."
  }
}

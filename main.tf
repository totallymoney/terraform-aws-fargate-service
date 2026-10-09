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
}

# A warning, not an error. Read it.
check "image_is_pinned" {
  assert {
    condition     = !endswith(var.container_image, ":latest")
    error_message = "container_image ends in :latest. Deployments will not be reproducible and a rollback may not get you the bytes you rolled back to."
  }
}

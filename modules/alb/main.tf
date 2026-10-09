# One load balancer, shared by every service that attaches to its listener.
# Services bring a host header and a rule; this module owns the public edge,
# the certificate, the WAF and the access logs.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  tags = merge(var.tags, { ManagedBy = "terraform" })

  # Suffix keeps the globally unique access log bucket name collision free
  # without putting the account id in it.
  suffix = substr(sha256("${local.account_id}-${var.name}"), 0, 8)
}

# A warning, not an error, so a deliberately open staging environment still
# ships. Read it.
check "alb_not_open_to_the_world" {
  assert {
    condition     = !contains(var.ingress_cidrs, "0.0.0.0/0")
    error_message = "ingress_cidrs contains 0.0.0.0/0. If a CDN is meant to be in front of this, the origin is now reachable directly and the CDN's protections can be bypassed."
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-alb"
  description = "Ingress to the ${var.name} load balancer"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-alb" })

  lifecycle {
    precondition {
      condition     = length(var.ingress_cidrs) > 0 || length(var.ingress_prefix_list_ids) > 0
      error_message = "Set ingress_cidrs or ingress_prefix_list_ids. With neither, nothing can reach the load balancer."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_cidr" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "HTTPS from ${each.key}"
  cidr_ipv4         = each.key
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https_prefix_list" {
  for_each = toset(var.ingress_prefix_list_ids)

  security_group_id = aws_security_group.this.id
  description       = "HTTPS from prefix list ${each.key}"
  prefix_list_id    = each.key
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Port 80 exists only to redirect. Allowing it from the same sources means a
# plain http link still works instead of timing out.
resource "aws_vpc_security_group_ingress_rule" "http_cidr" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "HTTP redirect from ${each.key}"
  cidr_ipv4         = each.key
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http_prefix_list" {
  for_each = toset(var.ingress_prefix_list_ids)

  security_group_id = aws_security_group.this.id
  description       = "HTTP redirect from prefix list ${each.key}"
  prefix_list_id    = each.key
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Egress to the tasks is not here. Each service opens the path to its own task
# security group, so adding a service does not mean editing this module.

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids

  idle_timeout               = var.idle_timeout
  enable_deletion_protection = var.enable_deletion_protection

  # Rejects requests with headers the load balancer cannot parse, which is one
  # class of request smuggling.
  drop_invalid_header_fields = true

  # HTTP/2 to the client, and the connection is closed if the client goes away
  # mid request.
  enable_http2                                = true
  enable_cross_zone_load_balancing            = true
  enable_tls_version_and_cipher_suite_headers = true

  access_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = var.name
    enabled = true
  }

  tags = local.tags

  depends_on = [aws_s3_bucket_policy.access_logs]
}

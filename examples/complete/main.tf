# Two services behind one load balancer, with a CDN in front.
#
# The point of the shape: the load balancer, its certificate, its WAF and its
# access logs are stood up once, and each service attaches to the listener with
# a rule claiming its own hostnames. Adding a third service is another module
# block, not another load balancer.
#
# Replace the certificate ARN, the images and the CDN ranges before applying.
# Nothing here creates DNS records or the CDN itself, because that usually
# lives with whoever owns the domain.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = "platform"
    }
  }
}

module "network" {
  source = "../../modules/network"

  name       = "${var.name}-${var.environment}"
  cidr_block = "10.0.0.0/16"

  availability_zone_count = 2

  # One NAT gateway is cheaper. In production, leave this false.
  single_nat_gateway = var.environment != "prod"
}

# Stood up once. Every service below shares it.
module "alb" {
  source = "../../modules/alb"

  name       = "${var.name}-${var.environment}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids

  certificate_arn = var.certificate_arn

  # Only the CDN reaches the origin. See the README for how to keep this list
  # current, and why an open origin undoes the CDN's protections.
  ingress_cidrs = var.cdn_ingress_cidrs

  # With a CDN in front, every request looks like it came from the CDN, so rate
  # limiting has to read the forwarded header instead of the source address.
  waf_rate_limit_forwarded_ip_header = "X-Forwarded-For"
}

module "web" {
  source = "../../"

  name   = "${var.name}-web-${var.environment}"
  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  listener_arn          = module.alb.listener_arn
  alb_security_group_id = module.alb.security_group_id
  alb_arn_suffix        = module.alb.arn_suffix

  host_headers           = ["www.example.com", "example.com"]
  listener_rule_priority = 100

  container_image = var.web_image
  container_port  = 8080

  environment = {
    NODE_ENV = "production"
  }

  # Read at start up by the execution role, which is granted access to exactly
  # these ARNs.
  secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = aws_ssm_parameter.database_url.arn
    },
  ]

  min_capacity  = var.environment == "prod" ? 2 : 1
  max_capacity  = var.environment == "prod" ? 10 : 2
  desired_count = var.environment == "prod" ? 2 : 1

  task_role_policy_json = data.aws_iam_policy_document.task.json
}

# A second service on the same load balancer. Different hostname, different
# priority, nothing else duplicated.
module "api" {
  source = "../../"

  name   = "${var.name}-api-${var.environment}"
  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  listener_arn          = module.alb.listener_arn
  alb_security_group_id = module.alb.security_group_id
  alb_arn_suffix        = module.alb.arn_suffix

  host_headers           = ["api.example.com"]
  listener_rule_priority = 200

  container_image = var.api_image
  container_port  = 8080

  min_capacity  = var.environment == "prod" ? 2 : 1
  max_capacity  = var.environment == "prod" ? 10 : 2
  desired_count = var.environment == "prod" ? 2 : 1
}

resource "aws_ssm_parameter" "database_url" {
  name  = "/${var.name}/${var.environment}/database-url"
  type  = "SecureString"
  value = "placeholder-set-out-of-band"

  # Terraform creates the parameter, something else sets the real value. This
  # keeps the secret out of state and out of the repository.
  lifecycle {
    ignore_changes = [value]
  }
}

# What the application itself can do. Start empty and add as you go.
data "aws_iam_policy_document" "task" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::example-assets-bucket/*"]
  }
}

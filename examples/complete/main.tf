# A public web service behind a CDN.
#
# Replace the certificate ARN, the image and the CDN ranges before applying.
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
      Service     = var.name
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

module "service" {
  source = "../../"

  name   = "${var.name}-${var.environment}"
  vpc_id = module.network.vpc_id

  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  certificate_arn = var.certificate_arn

  container_image = var.container_image
  container_port  = 8080

  # Only the CDN reaches the origin. See the README for how to keep this list
  # current, and why an open origin undoes the CDN's protections.
  alb_ingress_cidrs = var.cdn_ingress_cidrs

  # With a CDN in front, every request looks like it came from the CDN, so rate
  # limiting has to read the forwarded header instead of the source address.
  waf_rate_limit_forwarded_ip_header = "X-Forwarded-For"

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

# Mocked provider, so this runs with no AWS account and no credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  # KMS and S3 parse these at plan time, so the mock has to be real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-1" }
  }
  mock_data "aws_vpc" {
    defaults = { cidr_block = "10.0.0.0/16" }
  }
  mock_data "aws_elb_service_account" {
    defaults = { arn = "arn:aws:iam::156460612806:root" }
  }
}

variables {
  name               = "example"
  vpc_id             = "vpc-00000000000000000"
  public_subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
  private_subnet_ids = ["subnet-00000000000000003", "subnet-00000000000000004"]
  certificate_arn    = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  container_image    = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/example:v1"
  alb_ingress_cidrs  = ["203.0.113.0/24"]
}

run "tasks_are_not_reachable_from_the_internet" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get a public IP."
  }

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].subnets == toset(var.private_subnet_ids)
    error_message = "Tasks must run in the private subnets."
  }
}

run "hardened_container_defaults" {
  command = plan

  assert {
    condition     = local.container_definition.readonlyRootFilesystem == true
    error_message = "The container root filesystem should be read only by default."
  }

  assert {
    condition     = var.enable_execute_command == false
    error_message = "execute-command is a shell in production. It must be opt in."
  }

  assert {
    condition     = aws_ecr_repository.this[0].image_tag_mutability == "IMMUTABLE"
    error_message = "Mutable tags break rollbacks."
  }
}

run "tls_and_waf_defaults" {
  command = plan

  assert {
    condition     = aws_lb_listener.https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "The listener must refuse anything older than TLS 1.2."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "Invalid headers must be dropped."
  }

  assert {
    condition     = var.enable_waf == true
    error_message = "WAF is on by default because the module cannot know what sits in front of it."
  }
}

run "origin_secret_closes_the_listener_by_default" {
  command = plan

  variables {
    origin_secret_header = { name = "x-origin-token", value = "test-value" }
  }

  assert {
    condition     = aws_lb_listener.https.default_action[0].type == "fixed-response"
    error_message = "With an origin secret set, anything without the header must be refused."
  }

  assert {
    condition     = length(aws_lb_listener_rule.origin_secret) == 1
    error_message = "The forwarding rule for correct requests is missing."
  }
}

run "an_unreachable_load_balancer_is_a_plan_error" {
  command = plan

  variables {
    alb_ingress_cidrs           = []
    alb_ingress_prefix_list_ids = []
  }

  expect_failures = [aws_security_group.alb]
}

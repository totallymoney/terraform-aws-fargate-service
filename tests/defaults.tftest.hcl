# Mocked provider, so this runs with no AWS account and no credentials.
# The load balancer lives in modules/alb and has its own tests.

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
}

variables {
  name                   = "example"
  vpc_id                 = "vpc-00000000000000000"
  private_subnet_ids     = ["subnet-00000000000000003", "subnet-00000000000000004"]
  container_image        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/example:v1"
  listener_arn           = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:listener/app/example-alb/0000000000000000/1111111111111111"
  alb_security_group_id  = "sg-00000000000000000"
  alb_arn_suffix         = "app/example-alb/0000000000000000"
  host_headers           = ["www.example.com"]
  listener_rule_priority = 100
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

run "the_service_claims_only_its_own_hostnames" {
  command = plan

  assert {
    condition     = aws_lb_listener_rule.this.listener_arn == var.listener_arn
    error_message = "The service must attach to the shared listener rather than create its own."
  }

  assert {
    condition     = one(aws_lb_listener_rule.this.condition).host_header[0].values == toset(var.host_headers)
    error_message = "Without a host header condition the rule would answer for every hostname on the shared listener."
  }
}

run "only_this_service_is_opened_on_the_shared_security_group" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_tasks.security_group_id == var.alb_security_group_id
    error_message = "The path from the load balancer to these tasks must be opened on the shared group."
  }

  # Both security group ids are unknown until apply, so what is checkable here
  # is that the opening is a single port rather than a range.
  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_tasks.from_port == var.container_port && aws_vpc_security_group_egress_rule.alb_to_tasks.to_port == var.container_port
    error_message = "The load balancer should reach the container port and nothing else."
  }
}

run "origin_secret_is_required_by_the_rule" {
  command = plan

  variables {
    origin_secret_header = { name = "x-origin-token", value = "test-value" }
  }

  assert {
    condition     = length(aws_lb_listener_rule.this.condition) == 2
    error_message = "With an origin secret set, the rule must require the header as well as the hostname, otherwise anyone reaching the load balancer directly is served."
  }
}

run "a_service_with_no_hostname_is_a_plan_error" {
  command = plan

  variables {
    host_headers = []
  }

  expect_failures = [var.host_headers]
}

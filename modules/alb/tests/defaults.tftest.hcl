# Mocked provider, so this runs with no AWS account and no credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  # S3 parses these at plan time, so the mock has to be real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-1" }
  }
  mock_data "aws_elb_service_account" {
    defaults = { arn = "arn:aws:iam::156460612806:root" }
  }
}

variables {
  name            = "example"
  vpc_id          = "vpc-00000000000000000"
  subnet_ids      = ["subnet-00000000000000001", "subnet-00000000000000002"]
  certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  ingress_cidrs   = ["203.0.113.0/24"]
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

run "unmatched_requests_are_refused" {
  command = plan

  assert {
    condition     = aws_lb_listener.https.default_action[0].type == "fixed-response"
    error_message = "A hostname with no service rule must be refused, not handed to whichever service happens to be first."
  }

  assert {
    condition     = aws_lb_listener.https.default_action[0].fixed_response[0].status_code == "403"
    error_message = "The default action should refuse."
  }
}

run "the_shared_group_opens_nothing_outbound_on_its_own" {
  command = plan

  # Services add their own egress rules to this group. The module creating one
  # would mean every service on the load balancer could reach it.
  assert {
    condition     = length([for r in values(aws_vpc_security_group_ingress_rule.https_cidr) : r]) == length(var.ingress_cidrs)
    error_message = "Each allowed CIDR should get exactly one HTTPS ingress rule."
  }
}

run "an_unreachable_load_balancer_is_a_plan_error" {
  command = plan

  variables {
    ingress_cidrs           = []
    ingress_prefix_list_ids = []
  }

  expect_failures = [aws_security_group.this]
}

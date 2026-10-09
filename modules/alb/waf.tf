# A WAF in front of the origin. If a CDN with its own WAF is also in front,
# this is the layer that still applies when someone reaches the load balancer
# directly, which is the case the security group above is meant to prevent and
# this one is meant to survive.
#
# The managed groups run in count mode nowhere: they block. Watch the metrics
# after the first deploy and add rule exclusions rather than turning a group
# off wholesale.

resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = var.name
  scope = "REGIONAL"
  tags  = local.tags

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = { for i, g in var.waf_managed_rule_groups : g => i }

    content {
      name     = rule.key
      priority = rule.value + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "rate-limit"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = var.waf_rate_limit_forwarded_ip_header == null ? "IP" : "FORWARDED_IP"

        dynamic "forwarded_ip_config" {
          for_each = var.waf_rate_limit_forwarded_ip_header == null ? [] : [1]

          content {
            header_name       = var.waf_rate_limit_forwarded_ip_header
            fallback_behavior = "NO_MATCH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}

# The log group name has to start with aws-waf-logs-. AWS rejects anything else.
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  # Sampled requests include headers. Keep credentials and session cookies out
  # of the log.
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# This service's slice of a shared load balancer: a target group, a rule that
# claims its hostnames, and the one path through the load balancer's security
# group to its own tasks.
#
# The load balancer itself belongs to modules/alb. Several services share one.

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Priorities are evaluated low to high and must be unique on the listener.
# Leave gaps between services so one can be inserted later without renumbering
# the others, which would otherwise mean a rule being destroyed and recreated
# on a live listener.
resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.listener_rule_priority
  tags         = local.tags

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = var.host_headers
    }
  }

  # An IP allowlist proves a request came from the CDN, not that it came from
  # YOUR CDN account. Every CloudFront distribution shares the same ranges, and
  # Cloudflare is the same story. A shared secret the CDN adds as a header is
  # what actually ties the origin to your distribution.
  #
  # Both conditions must match, so without the header the request falls through
  # to the listener's default action and is refused.
  dynamic "condition" {
    for_each = var.origin_secret_header == null ? [] : [1]

    content {
      http_header {
        http_header_name = var.origin_secret_header.name
        values           = [var.origin_secret_header.value]
      }
    }
  }
}

# The load balancer reaches this service and nothing else learns about it. The
# rule lives with the service so adding one does not mean editing the shared
# load balancer.
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = var.alb_security_group_id
  description                  = "To the ${var.name} tasks"
  referenced_security_group_id = aws_security_group.tasks.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

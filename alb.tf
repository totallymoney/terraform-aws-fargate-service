# The load balancer is the only thing in this module with a public address.
# Everything else sits in private subnets and is reachable only through it.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Ingress to the ${var.name} load balancer"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-alb" })

  lifecycle {
    precondition {
      condition     = length(var.alb_ingress_cidrs) > 0 || length(var.alb_ingress_prefix_list_ids) > 0
      error_message = "Set alb_ingress_cidrs or alb_ingress_prefix_list_ids. With neither, nothing can reach the load balancer."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_cidr" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from ${each.key}"
  cidr_ipv4         = each.key
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_prefix_list" {
  for_each = toset(var.alb_ingress_prefix_list_ids)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from prefix list ${each.key}"
  prefix_list_id    = each.key
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Port 80 exists only to redirect. Allowing it from the same sources means a
# plain http link still works instead of timing out.
resource "aws_vpc_security_group_ingress_rule" "alb_http_cidr" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP redirect from ${each.key}"
  cidr_ipv4         = each.key
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_prefix_list" {
  for_each = toset(var.alb_ingress_prefix_list_ids)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP redirect from prefix list ${each.key}"
  prefix_list_id    = each.key
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# The load balancer talks to the tasks and nothing else.
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To the tasks"
  referenced_security_group_id = aws_security_group.tasks.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  tags              = local.tags

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn
  tags              = local.tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener_certificate" "additional" {
  for_each = toset(var.additional_certificate_arns)

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.key
}

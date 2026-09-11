# Three alarms worth having on any public service. The first two are scoped to
# the load balancer, which is what lets the deployment use them for rollback
# without creating a dependency cycle with the service.

locals {
  alarm_prefix  = var.name
  alarm_actions = var.alarm_topic_arns
}

# A rate, not a count. A fixed count of 5xx is either noise at high traffic or
# silence at low traffic.
resource "aws_cloudwatch_metric_alarm" "target_5xx_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-target-5xx-rate"
  alarm_description   = "Percentage of requests the application answered with 5xx"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alarm_5xx_rate_percent
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags

  metric_query {
    id          = "rate"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "5xx rate"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
        TargetGroup  = aws_lb_target_group.this.arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
        TargetGroup  = aws_lb_target_group.this.arn_suffix
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-unhealthy-targets"
  alarm_description   = "Targets failing the load balancer health check"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }
}

# Scoped to the service, so it is deliberately NOT used for deployment
# rollback: the service cannot depend on an alarm that depends on the service.
resource "aws_cloudwatch_metric_alarm" "running_tasks" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.alarm_prefix}-running-tasks-below-minimum"
  alarm_description   = "Fewer running tasks than the autoscaling floor"
  namespace           = "AWS/ECS"
  metric_name         = "RunningTaskCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.min_capacity
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = var.name
  }
}

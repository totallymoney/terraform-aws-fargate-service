resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = local.tags

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  dynamic "configuration" {
    for_each = var.enable_execute_command ? [1] : []

    content {
      execute_command_configuration {
        kms_key_id = var.kms_key_arn
        logging    = "OVERRIDE"

        log_configuration {
          cloud_watch_encryption_enabled = var.kms_key_arn != null
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec[0].name
        }
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# Tasks accept traffic from the load balancer only, and reach out over HTTPS
# plus DNS inside the VPC. Anything else has to be asked for.
resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Attached to the ${var.name} tasks"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-tasks" })
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "From the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tasks_https" {
  security_group_id = aws_security_group.tasks.id
  description       = "HTTPS out, for image pulls, logs, secrets and outbound APIs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# The VPC resolver lives inside the VPC CIDR, so DNS does not need to leave it.
resource "aws_vpc_security_group_egress_rule" "tasks_dns_udp" {
  security_group_id = aws_security_group.tasks.id
  description       = "DNS to the VPC resolver"
  cidr_ipv4         = local.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "tasks_dns_tcp" {
  security_group_id = aws_security_group.tasks.id
  description       = "DNS to the VPC resolver"
  cidr_ipv4         = local.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tasks_additional" {
  for_each = {
    for rule in var.additional_egress_rules :
    "${rule.protocol}-${rule.from_port}-${rule.to_port}-${rule.cidr_ipv4}" => rule
  }

  security_group_id = aws_security_group.tasks.id
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = local.tags

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([local.container_definition])
}

# Optional fields are merged in rather than set to null, so the registered task
# definition matches what Terraform holds and plans stay empty.
locals {
  container_definition = merge(
    {
      name      = var.name
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        for k, v in var.environment : { name = k, value = v }
      ]

      readonlyRootFilesystem = var.readonly_root_filesystem

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.container.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "container"
        }
      }
    },
    var.container_command == null ? {} : { command = var.container_command },
    length(var.secrets) == 0 ? {} : { secrets = var.secrets },
    var.container_health_check == null ? {} : {
      healthCheck = {
        command     = var.container_health_check.command
        interval    = var.container_health_check.interval
        timeout     = var.container_health_check.timeout
        retries     = var.container_health_check.retries
        startPeriod = var.container_health_check.start_period
      }
    },
  )
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type      = "FARGATE"
  platform_version = "LATEST"

  enable_execute_command = var.enable_execute_command

  # A failing deployment rolls itself back instead of sitting half applied.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # The circuit breaker catches tasks that fail to start. These alarms catch a
  # release that starts fine and then serves errors, which the breaker misses.
  dynamic "alarms" {
    for_each = var.enable_alarms && var.rollback_on_alarm ? [1] : []

    content {
      alarm_names = [
        aws_cloudwatch_metric_alarm.target_5xx_rate[0].alarm_name,
        aws_cloudwatch_metric_alarm.unhealthy_targets[0].alarm_name,
      ]
      enable   = true
      rollback = true
    }
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  propagate_tags = "SERVICE"
  tags           = local.tags

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.tasks.id]

    # Tasks reach the internet through NAT. A public IP here would make them
    # directly addressable.
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  # Autoscaling owns the task count once the service exists.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

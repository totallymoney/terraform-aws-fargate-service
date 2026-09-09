output "alb_dns_name" {
  description = "Load balancer hostname. Point your CDN origin or DNS record here."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone id of the load balancer, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "alb_arn" {
  description = "Load balancer ARN."
  value       = aws_lb.this.arn
}

output "alb_security_group_id" {
  description = "Load balancer security group."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group ARN."
  value       = aws_lb_target_group.this.arn
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_security_group_id" {
  description = "Security group on the tasks. Reference this from a database or cache security group instead of using CIDRs."
  value       = aws_security_group.tasks.id
}

output "task_role_arn" {
  description = "Role your application code runs as."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the task role, for attaching further policies."
  value       = aws_iam_role.task.name
}

output "execution_role_arn" {
  description = "Role ECS uses to pull the image and read secrets."
  value       = aws_iam_role.execution.arn
}

output "ecr_repository_url" {
  description = "Push images here."
  value       = try(aws_ecr_repository.this[0].repository_url, null)
}

output "log_group_name" {
  description = "Container log group."
  value       = aws_cloudwatch_log_group.container.name
}

output "access_logs_bucket" {
  description = "Bucket holding load balancer access logs."
  value       = aws_s3_bucket.access_logs.id
}

output "web_acl_arn" {
  description = "WAF attached to the load balancer."
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}

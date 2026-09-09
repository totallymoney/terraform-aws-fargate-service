output "alb_dns_name" {
  description = "Set this as the CDN origin."
  value       = module.service.alb_dns_name
}

output "ecr_repository_url" {
  description = "Push images here."
  value       = module.service.ecr_repository_url
}

output "task_role_arn" {
  value = module.service.task_role_arn
}

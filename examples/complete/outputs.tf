output "alb_dns_name" {
  description = "Set this as the CDN origin. Both services answer on it, routed by hostname."
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "For a Route 53 alias record."
  value       = module.alb.zone_id
}

output "web_ecr_repository_url" {
  description = "Push web images here."
  value       = module.web.ecr_repository_url
}

output "api_ecr_repository_url" {
  description = "Push api images here."
  value       = module.api.ecr_repository_url
}

output "web_task_role_arn" {
  value = module.web.task_role_arn
}

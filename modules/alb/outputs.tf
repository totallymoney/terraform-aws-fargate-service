output "arn" {
  description = "Load balancer ARN."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "Load balancer hostname. Point your CDN origin or DNS record here."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone id of the load balancer, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "listener_arn" {
  description = "HTTPS listener. Pass this to each service module."
  value       = aws_lb_listener.https.arn
}

output "security_group_id" {
  description = "Load balancer security group. Pass this to each service module so it can open the path to its own tasks."
  value       = aws_security_group.this.id
}

output "access_logs_bucket" {
  description = "Bucket holding load balancer access logs."
  value       = aws_s3_bucket.access_logs.id
}

output "web_acl_arn" {
  description = "WAF attached to the load balancer."
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}

output "arn_suffix" {
  description = "Load balancer ARN suffix, used as a CloudWatch dimension. Pass this to each service module so its alarms can scope to this load balancer."
  value       = aws_lb.this.arn_suffix
}

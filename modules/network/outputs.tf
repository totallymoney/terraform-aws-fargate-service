output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnets. Load balancers only."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnets. Put your tasks here."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "AZs in use."
  value       = local.azs
}

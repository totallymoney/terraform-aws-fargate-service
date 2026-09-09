variable "name" {
  type        = string
  description = "Prefix for every resource in this module."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "Must be 3-32 characters, lowercase letters, digits and hyphens."
  }
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR. Subnets are cut out of it automatically. Pick a range that does not overlap anything you might peer with later."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) && tonumber(split("/", var.cidr_block)[1]) <= 20
    error_message = "Must be valid CIDR of /20 or larger."
  }
}

variable "availability_zone_count" {
  type        = number
  description = "Number of AZs to spread across. Two is the minimum for a load balancer."
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4
    error_message = "Between 2 and 4."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "Route all private subnets through one NAT gateway. Cheaper, but the AZ holding it becomes a single point of failure. Leave false for production."
  default     = false
}

variable "enable_flow_logs" {
  type        = bool
  description = "Send VPC flow logs to CloudWatch Logs. This is what you read after an incident, so keep it on."
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "Retention for the flow log group."
  default     = 90
}

variable "kms_key_arn" {
  type        = string
  description = "CMK for the flow log group. Leave null to use CloudWatch Logs default encryption."
  default     = null
}

variable "enable_vpc_endpoints" {
  type        = bool
  description = <<-EOT
    Create interface endpoints for ECR, CloudWatch Logs, Secrets Manager, SSM and KMS,
    plus a gateway endpoint for S3. Keeps image pulls and secret reads off the public
    internet. Interface endpoints are charged per hour per AZ, so this is off by default.
  EOT
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

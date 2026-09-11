variable "name" {
  type        = string
  description = "Prefix for every resource in this module."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "Must be 3-32 characters, lowercase letters, digits and hyphens."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC to build in."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets for the load balancer. At least two, in different AZs."

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "A load balancer needs at least two subnets in different AZs."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets for the tasks. These should have no route to an internet gateway."

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one subnet is required."
  }
}

# --- Who can reach the load balancer ---

variable "alb_ingress_cidrs" {
  type        = list(string)
  description = <<-EOT
    CIDRs allowed to reach the load balancer on 443.

    If a CDN sits in front, put the CDN's ranges here and nothing else. Leaving
    this open to 0.0.0.0/0 means the origin can be reached directly, which
    bypasses the CDN's WAF, rate limiting and bot rules, and lets anyone who
    finds the DNS name hit your application.
  EOT
  default     = []
}

variable "alb_ingress_prefix_list_ids" {
  type        = list(string)
  description = "Managed prefix lists allowed on 443. Use `com.amazonaws.global.cloudfront.origin-facing` when CloudFront is the CDN, so the list stays current on its own."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Make the load balancer internal. Set true when traffic arrives over a private link rather than from the internet."
  default     = false
}

# --- TLS ---

variable "certificate_arn" {
  type        = string
  description = "ACM certificate for the HTTPS listener."
}

variable "additional_certificate_arns" {
  type        = list(string)
  description = "Extra certificates on the same listener, for other hostnames."
  default     = []
}

variable "ssl_policy" {
  type        = string
  description = "Listener TLS policy. The default allows TLS 1.3 and 1.2 and nothing older."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# --- Load balancer behaviour ---

variable "enable_deletion_protection" {
  type        = bool
  description = "Stop the load balancer being deleted by accident."
  default     = true
}

variable "idle_timeout" {
  type        = number
  description = "Seconds an idle connection is held open."
  default     = 60
}

variable "access_logs_retention_days" {
  type        = number
  description = "Days to keep load balancer access logs."
  default     = 90
}

# --- Container ---

variable "container_image" {
  type        = string
  description = "Image to run. Pin a digest or an immutable tag, never `latest`."
}

variable "container_port" {
  type        = number
  description = "Port the container listens on."
  default     = 8080
}

variable "cpu" {
  type        = number
  description = "Task CPU units. 256 is a quarter of a vCPU."
  default     = 512
}

variable "memory" {
  type        = number
  description = "Task memory in MiB. Must be a valid pairing with cpu."
  default     = 1024
}

variable "environment" {
  type        = map(string)
  description = "Plain environment variables. Never put credentials here, they are visible in the task definition."
  default     = {}
}

variable "secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "Secrets injected at start up from SSM Parameter Store or Secrets Manager. The execution role is granted read on exactly these ARNs and nothing more."
  default     = []
}

variable "readonly_root_filesystem" {
  type        = bool
  description = "Mount the container filesystem read only. Turn off only if the application genuinely writes to disk."
  default     = true
}

variable "container_command" {
  type        = list(string)
  description = "Override the image command."
  default     = null
}

variable "container_health_check" {
  type = object({
    command      = list(string)
    interval     = optional(number, 30)
    timeout      = optional(number, 5)
    retries      = optional(number, 3)
    start_period = optional(number, 30)
  })
  description = "Docker level health check. The load balancer health check below is separate and usually enough."
  default     = null
}

# --- Service ---

variable "desired_count" {
  type        = number
  description = "Starting task count. Autoscaling takes over after the first deploy."
  default     = 2
}

variable "min_capacity" {
  type        = number
  description = "Autoscaling floor. Two or more keeps the service up during an AZ event."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Autoscaling ceiling. Also your cost ceiling."
  default     = 6
}

variable "target_cpu_utilization" {
  type        = number
  description = "Average CPU percentage autoscaling aims for."
  default     = 60
}

variable "health_check_path" {
  type        = string
  description = "Path the load balancer requests. Should not need a database to answer."
  default     = "/health"
}

variable "health_check_matcher" {
  type        = string
  description = "Status codes counted as healthy."
  default     = "200"
}

variable "deregistration_delay" {
  type        = number
  description = "Seconds to drain a task before stopping it."
  default     = 30
}

variable "enable_execute_command" {
  type        = bool
  description = "Allow `aws ecs execute-command` into running tasks. Off by default: it is a shell in production. When on, every session is logged to CloudWatch."
  default     = false
}

# --- Egress ---

variable "additional_egress_rules" {
  type = list(object({
    description = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_ipv4   = string
  }))
  description = "Extra egress the task needs. The default allows HTTPS out and DNS inside the VPC, nothing else."
  default     = []
}

# --- Logs and keys ---

variable "log_retention_days" {
  type        = number
  description = "Retention for the container log group."
  default     = 90
}

variable "kms_key_arn" {
  type        = string
  description = "CMK for the log groups. Leave null to use CloudWatch Logs default encryption."
  default     = null
}

# --- WAF ---

variable "enable_waf" {
  type        = bool
  description = "Attach a WAF with the AWS managed baseline rule groups and a rate limit."
  default     = true
}

variable "waf_rate_limit" {
  type        = number
  description = "Requests per five minutes from one IP before it is blocked."
  default     = 2000
}

variable "waf_managed_rule_groups" {
  type        = list(string)
  description = "AWS managed rule groups, applied in order."
  default = [
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesAmazonIpReputationList",
  ]
}

# --- ECR ---

variable "create_ecr_repository" {
  type        = bool
  description = "Create a repository for this service's images."
  default     = true
}

variable "ecr_image_tag_mutability" {
  type        = string
  description = "IMMUTABLE stops a tag being repointed at different bytes after review. Change to MUTABLE only if your pipeline pushes a moving tag."
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.ecr_image_tag_mutability)
    error_message = "Must be IMMUTABLE or MUTABLE."
  }
}

variable "ecr_untagged_expiry_days" {
  type        = number
  description = "Days before untagged images are removed."
  default     = 14
}

variable "task_role_policy_json" {
  type        = string
  description = "IAM policy for the task role, which is what your application code uses. Keep it to the resources this service actually touches."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "cpu_architecture" {
  type        = string
  description = "ARM64 costs about 20 percent less per task, but the image has to be built for it. Check your image before switching."
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "Must be X86_64 or ARM64."
  }
}

variable "waf_rate_limit_forwarded_ip_header" {
  type        = string
  description = <<-EOT
    Header carrying the real client IP, used for rate limiting.

    When a CDN sits in front, every request arrives from the CDN's addresses, so
    an IP based rate limit counts all of your traffic as one client and never
    fires. Set this to the header your CDN sends, usually X-Forwarded-For.
    Leave null only when clients connect to the load balancer directly.
  EOT
  default     = null
}

variable "origin_secret_header" {
  type = object({
    name  = string
    value = string
  })
  description = <<-EOT
    Header the CDN adds and the load balancer requires. Requests without it get
    a 403 before they reach a task.

    Restricting ingress by CDN address range proves a request came from the CDN,
    not that it came from YOUR distribution. Every customer of that CDN shares
    the same ranges, so anyone can point their own distribution at your origin.
    This closes that.

    The value is held in Terraform state. Generate it outside Terraform and read
    it from your secret store rather than committing it.
  EOT
  default     = null
  sensitive   = true
}

variable "enable_alarms" {
  type        = bool
  description = "Create the service health alarms."
  default     = true
}

variable "alarm_topic_arns" {
  type        = list(string)
  description = "SNS topics the alarms notify. Pass the topic from the account baseline."
  default     = []
}

variable "alarm_5xx_rate_percent" {
  type        = number
  description = "Percentage of requests answered with 5xx before the alarm fires."
  default     = 5
}

variable "rollback_on_alarm" {
  type        = bool
  description = "Roll a deployment back when the load balancer alarms fire. Without this a deployment only rolls back if tasks fail to start, so a release that starts cleanly and then returns errors stays up."
  default     = true
}

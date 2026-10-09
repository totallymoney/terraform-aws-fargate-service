variable "name" {
  type        = string
  description = "Name for the load balancer and everything attached to it."
}

variable "vpc_id" {
  type        = string
  description = "VPC the load balancer sits in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the load balancer. At least two, in different AZs."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "A load balancer needs at least two subnets in different AZs."
  }
}

variable "internal" {
  type        = bool
  description = "Make the load balancer internal. Set true when traffic arrives over a private link rather than from the internet."
  default     = false
}

# --- Ingress ---

variable "ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the load balancer. Set this or ingress_prefix_list_ids. There is no default on purpose: an origin open to the world is a decision, not an oversight."
  default     = []
}

variable "ingress_prefix_list_ids" {
  type        = list(string)
  description = "Managed prefix lists allowed to reach the load balancer, for example a CDN's."
  default     = []
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

# --- Behaviour ---

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

variable "unmatched_request_status_code" {
  type        = string
  description = "Status returned when a request matches no service rule. 403 says the origin exists but you are not meant to be here; 404 gives less away."
  default     = "403"
}

# --- WAF ---

variable "enable_waf" {
  type        = bool
  description = "Attach a WAF with the AWS managed baseline rule groups and a rate limit. One WAF covers every service on this load balancer."
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

# --- Logs ---

variable "log_retention_days" {
  type        = number
  description = "Retention for the WAF log group."
  default     = 90
}

variable "kms_key_arn" {
  type        = string
  description = "CMK for the WAF log group. Leave null to use CloudWatch Logs default encryption."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to everything this module creates."
  default     = {}
}

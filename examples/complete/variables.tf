variable "name" {
  type        = string
  description = "Service name."
  default     = "example-web"
}

variable "environment" {
  type        = string
  description = "Environment name, used in resource names and tags."
  default     = "test"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "eu-west-1"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate in the same region as the load balancer."
}

variable "web_image" {
  type        = string
  description = "Image for the web service. Use a digest or an immutable tag."
}

variable "api_image" {
  type        = string
  description = "Image for the api service. Use a digest or an immutable tag."
}

variable "cdn_ingress_cidrs" {
  type        = list(string)
  description = "CDN ranges allowed to reach the origin. See the README."
}

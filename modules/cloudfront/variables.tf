# ===========================================
# CloudFront Variables
# ===========================================

variable "name_prefix" {
  description = "Prefix for CloudFront resources"
  type        = string
  default     = "cat"
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
}

variable "default_root_object" {
  description = "Default root object"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "custom_header_value" {
  description = "Custom header value to verify requests from CloudFront"
  type        = string
  default     = "CloudFrontOriginVerify"
}

variable "aliases" {
  description = "Custom domain names (CNAMEs) for CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

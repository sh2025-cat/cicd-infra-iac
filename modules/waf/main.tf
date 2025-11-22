# ===========================================
# WAF Web ACL for CloudFront
# ===========================================

# GitHub Webhook IP Set (GitHub Meta API: https://api.github.com/meta)
resource "aws_wafv2_ip_set" "github_webhooks" {
  name               = "${var.name_prefix}-github-webhook-ips"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  # GitHub Hooks IP ranges (from https://api.github.com/meta)
  addresses = [
    "192.30.252.0/22",
    "185.199.108.0/22",
    "140.82.112.0/20",
    "143.55.64.0/20",
    "20.201.28.151/32",
    "20.205.243.166/32",
    "102.133.202.242/32",
    "20.248.137.48/32",
    "20.207.73.82/32",
    "20.27.177.113/32",
    "20.200.245.247/32",
    "20.233.54.53/32",
    "20.201.28.152/32",
    "20.205.243.160/32",
    "102.133.202.246/32",
    "20.248.137.50/32",
    "20.207.73.83/32",
    "20.27.177.118/32",
    "20.200.245.248/32",
    "20.233.54.52/32"
  ]

  tags = var.tags
}

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name  = "${var.name_prefix}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # GitHub Webhook Allow Rule (highest priority)
  rule {
    name     = "AllowGitHubWebhooks"
    priority = 0

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.github_webhooks.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
      metric_name                = "${var.name_prefix}-github-webhooks"
      sampled_requests_enabled   = var.enable_sampled_requests
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
      metric_name                = "${var.name_prefix}-common-rule-set"
      sampled_requests_enabled   = var.enable_sampled_requests
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
      metric_name                = "${var.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = var.enable_sampled_requests
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
      metric_name                = "${var.name_prefix}-sqli-rule-set"
      sampled_requests_enabled   = var.enable_sampled_requests
    }
  }

  # Rate Limiting Rule (DDoS Protection)
  rule {
    name     = "RateLimitRule"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
      metric_name                = "${var.name_prefix}-rate-limit"
      sampled_requests_enabled   = var.enable_sampled_requests
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = var.enable_sampled_requests
  }

  tags = var.tags
}

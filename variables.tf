variable "app_name" {
  description = "Application name used in resource names and tags"
  type        = string
}

variable "app_env" {
  description = "Environment name (e.g. stg, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are created"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID, used in IAM and S3 bucket policies"
  type        = string
}

variable "parameter_path" {
  description = "SSM parameter path prefix to back up, e.g. /cover/stg"
  type        = string
}

variable "schedule" {
  description = "EventBridge cron schedule expression for the backup (without the 'cron()' wrapper)"
  type        = string
  default     = "0 3 * * ? *"
}

variable "retention_days" {
  description = "Number of days to retain noncurrent S3 object versions before expiring them"
  type        = number
  default     = 90
}

variable "enabled" {
  description = "Whether the EventBridge backup schedule is enabled"
  type        = bool
  default     = true
}

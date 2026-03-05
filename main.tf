data "aws_caller_identity" "current" {}

resource "random_id" "this" {
  byte_length = 4
}

/*
 * KMS key for SSM parameter backups
 */
resource "aws_kms_key" "this" {
  description             = "Encrypts SSM parameter backups for ${var.app_name}-${var.app_env}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key.json

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "kms_key" {
  # Required: give the account root full access so the key remains manageable via IAM
  statement {
    sid       = "AllowRootFullAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Deny key deletion scheduling to everyone except explicitly listed admins
  statement {
    sid     = "DenyScheduleKeyDeletionToNonAdmins"
    effect  = "Deny"
    actions = ["kms:ScheduleKeyDeletion"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.kms_admin_arns,
      )
    }
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/ssm-backup-${var.app_name}-${var.app_env}"
  target_key_id = aws_kms_key.this.key_id
}

/*
 * Create S3 bucket to receive SSM backup access logs
 */
resource "aws_s3_bucket" "logs" {
  bucket        = "ssm-backup-logs-${var.app_name}-${var.app_env}-${random_id.this.hex}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "logs" {
  depends_on = [aws_s3_bucket_public_access_block.logs]
  bucket     = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3LogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/access-logs/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_s3_bucket.this.arn,
              aws_s3_bucket.logs.arn,
            ]
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_logging" "logs" {
  bucket        = aws_s3_bucket.logs.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 90
    }
  }
}

/*
 * Create S3 bucket for SSM parameter backups
 */
resource "aws_s3_bucket" "this" {
  bucket        = "ssm-backup-${var.app_name}-${var.app_env}-${random_id.this.hex}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  depends_on = [aws_s3_bucket_public_access_block.this]
  bucket     = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  depends_on = [aws_s3_bucket_versioning.this]
  bucket     = aws_s3_bucket.this.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}

/*
 * Create IAM role and policy for SSM backup Lambda
 */
resource "aws_iam_role" "this" {
  name = "ssm-backup-${var.app_name}-${var.app_env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "ssm-backup-${var.app_name}-${var.app_env}"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_path}/*"
      },
      {
        # Needed to decrypt SecureString parameters (default aws/ssm key or CMK)
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = aws_kms_key.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/ssm-backup-${var.app_name}-${var.app_env}:*"
      },
    ]
  })
}

/*
 * Create CloudWatch log group for SSM backup Lambda
 */
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/ssm-backup-${var.app_name}-${var.app_env}"
  retention_in_days = 60
}

/*
 * Package Lambda function code
 */
data "archive_file" "this" {
  type             = "zip"
  source_file      = "${path.module}/lambda/ssm_backup.py"
  output_path      = "${path.module}/lambda/ssm_backup_lambda.zip"
  output_file_mode = "0666"
}

/*
 * Create Lambda function for SSM parameter backup
 */
resource "aws_lambda_function" "this" {
  function_name    = "ssm-backup-${var.app_name}-${var.app_env}"
  role             = aws_iam_role.this.arn
  runtime          = "python3.10"
  handler          = "ssm_backup.handler"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  timeout          = 300
  depends_on       = [aws_cloudwatch_log_group.this]

  environment {
    variables = {
      SSM_PATH   = var.parameter_path
      S3_BUCKET  = aws_s3_bucket.this.bucket
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
      KMS_KEY_ID = aws_kms_key.this.arn
    }
  }
}

/*
 * Allow EventBridge to invoke the Lambda
 */
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

/*
 * CloudWatch configuration to start SSM parameter backup
 */
resource "aws_cloudwatch_event_rule" "this" {
  name                = "ssm-backup-${var.app_name}-${var.app_env}"
  description         = "Start SSM parameter backup on cron schedule"
  schedule_expression = "cron(${var.schedule})"
  state               = var.enabled ? "ENABLED" : "DISABLED"
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "run-ssm-backup-${var.app_name}-${var.app_env}"
  rule      = aws_cloudwatch_event_rule.this.name
  arn       = aws_lambda_function.this.arn
}

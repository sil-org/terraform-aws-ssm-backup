# Terraform Module for AWS SSM Parameter Store Backup

This module is used to create scheduled backups of AWS SSM Parameter Store parameters to S3 using a Lambda function and EventBridge.

## Resources Managed

- KMS Encryption key and alias
- S3 backup bucket (versioned, KMS-encrypted)
- S3 access-log bucket
- S3 bucket policies, logging, lifecycle configurations
- IAM Role and Policy (Lambda execution)
- CloudWatch Log Group
- Lambda function (Python 3.10)
- EventBridge rule and target

This module is published in [Terraform Registry](https://registry.terraform.io/modules/sil-org/ssm-backup/aws/latest).

## Example Usage

```hcl
module "ssm_backup" {
  source  = "sil-org/ssm-backup/aws"
  version = "~> 1.0"

  app_name       = var.app_name
  app_env        = var.app_env
  aws_region     = var.aws_region
  aws_account_id = local.aws_account
  parameter_path = "/${var.app_name}/${var.app_env}"
}
```

## Inputs

- `app_name` (string, required): Application name used in resource names
- `app_env` (string, required): Environment name (e.g. stg, prod)
- `aws_region` (string, required): AWS region where resources are created
- `aws_account_id` (string, required): AWS account ID, used in IAM and S3 bucket policies
- `parameter_path` (string, required): SSM parameter path prefix to back up, e.g. `/cover/stg`
- `schedule` (string, default: `"0 3 * * ? *"`): EventBridge cron schedule expression (without the `cron()` wrapper)
- `retention_days` (number, default: `90`): Days to retain noncurrent S3 object versions before expiring
- `enabled` (bool, default: `true`): Whether the EventBridge backup schedule is enabled

## Outputs

- `s3_bucket_id`: Name of the S3 bucket storing SSM parameter backups
- `s3_bucket_arn`: ARN of the S3 bucket storing SSM parameter backups
- `lambda_arn`: ARN of the SSM backup Lambda function
- `kms_key_arn`: ARN of the KMS key used to encrypt SSM parameter backups

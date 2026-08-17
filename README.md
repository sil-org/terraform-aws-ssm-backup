# Terraform Module for AWS SSM Parameter Store Backup

This module is used to create scheduled backups of AWS SSM Parameter Store parameters to S3 using a Lambda function and EventBridge. It also provisions a manually-invoked Lambda for restoring parameters from a backup.

## Resources Managed

- KMS Encryption key and alias
- S3 backup bucket (versioned, KMS-encrypted)
- S3 access-log bucket
- S3 bucket policies, logging, lifecycle configurations
- IAM Role and Policy (Lambda execution)
- CloudWatch Log Group
- Backup and restore Lambda functions (Python 3.12)
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
  parameter_path = "/${var.app_name}/${var.app_env}"
}
```

## Restore

A restore Lambda (`ssm-restore-<app_name>-<app_env>`) is created alongside the backup Lambda. It's invoked manually and reads the same backup file the backup Lambda writes.

```sh
aws lambda invoke \
  --function-name ssm-restore-<app_name>-<app_env> \
  --payload '{"dry_run": false}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```

Optional payload fields: `dry_run` (default `true`, previews without writing), `version_id` (restore from a specific S3 backup version), `parameters` (restrict to specific parameter names).

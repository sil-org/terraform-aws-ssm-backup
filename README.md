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
  parameter_path = "/${var.app_name}/${var.app_env}"
}
```

# Terraform Module for AWS SSM Parameter Store Backup

This module is used to create scheduled backups of AWS SSM Parameter Store parameters to S3 using a Lambda function and EventBridge. It also provisions a manually-invoked Lambda for restoring parameters from a backup.

## Resources Managed

- KMS Encryption key and alias
- S3 backup bucket (versioned, KMS-encrypted)
- S3 access-log bucket
- S3 bucket policies, logging, lifecycle configurations
- IAM Roles and Policies (Lambda execution)
- CloudWatch Log Groups
- Backup Lambda function (Python 3.12)
- Restore Lambda function (Python 3.12, optional via `enable_restore`)
- EventBridge rule and target (backup schedule only)

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

A restore Lambda (`ssm-restore-<app_name>-<app_env>`) is created alongside the backup Lambda. It is **invoked manually** — there is no schedule for it — and reads the same backup file the backup Lambda writes.

```sh
aws lambda invoke \
  --function-name ssm-restore-<app_name>-<app_env> \
  --payload '{"dry_run": false}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```

Invoke payload options (all optional):

| Field | Default | Description |
|---|---|---|
| `dry_run` | `true` | When `true`, reports which parameters would be restored without writing anything. Set to `false` to actually apply the restore. |
| `version_id` | latest | S3 object version ID of the backup file to restore from, for point-in-time recovery (the backup bucket is versioned). |
| `parameters` | all | List of parameter names to restrict the restore to, instead of restoring everything in the backup file. |

Notes:

- Restore only ever creates or overwrites parameters present in the backup file (`Overwrite=True`) — it never deletes a parameter, even one that no longer exists in the backup.
- The backup file doesn't record a custom KMS key ID used for `SecureString` parameters, so restored `SecureString` values are re-encrypted with the default `alias/aws/ssm` key.
- Set `enable_restore = false` to skip creating the restore Lambda and its IAM role entirely.

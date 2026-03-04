output "s3_bucket_id" {
  description = "Name of the S3 bucket storing SSM parameter backups"
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing SSM parameter backups"
  value       = aws_s3_bucket.this.arn
}

output "lambda_arn" {
  description = "ARN of the SSM backup Lambda function"
  value       = aws_lambda_function.this.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt SSM parameter backups"
  value       = aws_kms_key.this.arn
}

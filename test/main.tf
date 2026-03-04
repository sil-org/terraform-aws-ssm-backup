module "minimal" {
  source = "../"

  app_name       = "myapp"
  app_env        = "stg"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  parameter_path = "/myapp/stg"
}

module "full" {
  source = "../"

  app_name       = "myapp"
  app_env        = "prod"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  parameter_path = "/myapp/prod"
  schedule       = "0 2 * * ? *"
  retention_days = 180
  enabled        = true
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

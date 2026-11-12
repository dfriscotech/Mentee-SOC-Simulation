terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "default"

  assume_role {
    role_arn = "arn:aws:iam::630256878267:role/OrganizationAccountAccessRole"
  }
}

data "aws_caller_identity" "scenario" {}

locals {
  bucket_name = "mentee-soc-s3-anomalous-access-${data.aws_caller_identity.scenario.account_id}-lab"

  training_objects = {
    "case-files/incident-001.txt" = "Synthetic training record. No real customer or production data."
    "case-files/incident-002.txt" = "Synthetic training record. Access activity is for analyst investigation."
    "reports/monthly-summary.txt" = "Synthetic monthly summary for the SOC lab."
  }
}

resource "aws_s3_bucket" "scenario" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = {
    Project     = "mentee-soc-simulation"
    Scenario    = "s3-anomalous-access"
    Environment = "lab"
  }
}

resource "aws_s3_bucket_public_access_block" "scenario" {
  bucket = aws_s3_bucket.scenario.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "scenario" {
  bucket = aws_s3_bucket.scenario.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scenario" {
  bucket = aws_s3_bucket.scenario.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "scenario" {
  bucket = aws_s3_bucket.scenario.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "training" {
  for_each = local.training_objects

  bucket       = aws_s3_bucket.scenario.id
  key          = each.key
  content      = each.value
  content_type = "text/plain"

  server_side_encryption = "AES256"
}

output "scenario_account_id" {
  description = "AWS account hosting the S3 anomalous access scenario"
  value       = data.aws_caller_identity.scenario.account_id
}

output "scenario_bucket_name" {
  description = "Private S3 bucket containing synthetic investigation objects"
  value       = aws_s3_bucket.scenario.id
}
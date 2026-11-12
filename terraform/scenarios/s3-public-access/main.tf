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
    role_arn = "arn:aws:iam::416716458645:role/OrganizationAccountAccessRole"
  }
}

data "aws_caller_identity" "scenario" {}

variable "simulate_bpa_disabled" {
  description = "Set true only for the isolated Block Public Access training exercise"
  type        = bool
  default     = false
}

locals {
  bucket_name = "mentee-soc-s3-public-access-${data.aws_caller_identity.scenario.account_id}-lab"
}

resource "aws_s3_bucket" "scenario" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = {
    Project     = "mentee-soc-simulation"
    Scenario    = "s3-public-access"
    Environment = "lab"
  }
}

resource "aws_s3_bucket_public_access_block" "scenario" {
  bucket = aws_s3_bucket.scenario.id

  block_public_acls       = !var.simulate_bpa_disabled
  block_public_policy     = !var.simulate_bpa_disabled
  ignore_public_acls      = !var.simulate_bpa_disabled
  restrict_public_buckets = !var.simulate_bpa_disabled
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

output "scenario_account_id" {
  description = "AWS account hosting the S3 public access scenario"
  value       = data.aws_caller_identity.scenario.account_id
}

output "scenario_bucket_name" {
  description = "Empty S3 bucket used for the public access scenario"
  value       = aws_s3_bucket.scenario.id
}
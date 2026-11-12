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
}

provider "aws" {
  alias   = "logging"
  region  = "us-east-2"
  profile = "default"

  assume_role {
    role_arn = "arn:aws:iam::528847740588:role/OrganizationAccountAccessRole"
  }
}

data "aws_caller_identity" "management" {}

data "aws_caller_identity" "logging" {
  provider = aws.logging
}

data "aws_organizations_organization" "current" {}

data "aws_guardduty_detector" "security_logging" {
  provider = aws.logging
}

resource "aws_guardduty_organization_configuration" "organization" {
  provider = aws.logging

  detector_id                      = data.aws_guardduty_detector.security_logging.id
  auto_enable_organization_members = "ALL"
}

resource "aws_guardduty_member_detector_feature" "s3_anomalous_access" {
  provider = aws.logging

  detector_id = data.aws_guardduty_detector.security_logging.id
  account_id  = "630256878267"
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"

  depends_on = [
    aws_guardduty_organization_configuration.organization
  ]
}

locals {
  trail_name = "mentee-soc-org-trail"

  trail_arn = "arn:aws:cloudtrail:us-east-2:${data.aws_caller_identity.management.account_id}:trail/${local.trail_name}"

  bucket_name = "mentee-soc-cloudtrail-${data.aws_caller_identity.logging.account_id}"
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/soc-lab/cloudtrail"
  retention_in_days = 30

  tags = {
    Project     = "mentee-soc-simulation"
    Purpose     = "cloudtrail-investigations"
    Environment = "lab"
  }
}

resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "soc-lab-cloudtrail-to-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name = "soc-lab-cloudtrail-log-delivery"
  role = aws_iam_role.cloudtrail_to_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.cloudtrail.arn}:log-stream:${data.aws_caller_identity.management.account_id}_CloudTrail_us-east-2*",
          "${aws_cloudwatch_log_group.cloudtrail.arn}:log-stream:${data.aws_organizations_organization.current.id}_*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "cloudtrail" {
  provider = aws.logging
  bucket   = local.bucket_name

  tags = {
    Project     = "mentee-soc-simulation"
    Purpose     = "central-cloudtrail-logs"
    Environment = "lab"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  provider = aws.logging
  bucket   = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "CloudTrailWriteManagementAccount"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.management.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "CloudTrailWriteOrganization"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "organization" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cloudwatch.arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_to_cloudwatch
  ]
}

output "cloudtrail_arn" {
  description = "Organization CloudTrail ARN"
  value       = aws_cloudtrail.organization.arn
}

output "cloudtrail_bucket_name" {
  description = "Central S3 bucket for organization CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_log_group_name" {
  description = "CloudWatch Logs group for CloudTrail events"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the delegated security account"
  value       = data.aws_guardduty_detector.security_logging.id
}
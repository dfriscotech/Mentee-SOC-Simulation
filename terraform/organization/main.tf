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
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "current" {}

output "caller_account_id" {
  description = "AWS account used by the active CLI profile"
  value       = data.aws_caller_identity.current.account_id
}

output "organization_id" {
  description = "AWS Organizations ID"
  value       = data.aws_organizations_organization.current.id
}

output "management_account_id" {
  description = "Organization management account ID"
  value       = data.aws_organizations_organization.current.master_account_id
}

output "root_id" {
  description = "Organization root ID"
  value       = data.aws_organizations_organization.current.roots[0].id
}

output "organization_accounts" {
  description = "Account names, IDs, and states; no email addresses"
  value = [
    for account in data.aws_organizations_organization.current.accounts : {
      name  = account.name
      id    = account.id
      state = account.state
    }
  ]
}

locals {
  organization_accounts_by_id = {
    for account in data.aws_organizations_organization.current.accounts :
    account.id => account
  }
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.current.roots[0].id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "lab" {
  name      = "Lab"
  parent_id = data.aws_organizations_organization.current.roots[0].id

  tags = {
    Environment = "Lab"
    Owner       = "Devante"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "s3_public_access" {
  name      = "soc-lab-s3-public-access"
  email     = local.organization_accounts_by_id["416716458645"].email
  parent_id = aws_organizations_organizational_unit.lab.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "s3_anomalous_access" {
  name      = "soc-lab-s3-anomalous-access"
  email     = local.organization_accounts_by_id["630256878267"].email
  parent_id = aws_organizations_organizational_unit.lab.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "ssh_bruteforce" {
  name      = "soc-lab-ssh-bruteforce"
  email     = local.organization_accounts_by_id["114128048968"].email
  parent_id = aws_organizations_organizational_unit.lab.id

  tags = {
    Project  = "mentee-soc-simulation"
    Scenario = "ssh-bruteforce"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "security_logging" {
  name      = "soc-security-logging"
  email     = local.organization_accounts_by_id["528847740588"].email
  parent_id = aws_organizations_organizational_unit.security.id

  tags = {
    Project = "mentee-soc-simulation"
    Purpose = "security-logging"
  }

  lifecycle {
    prevent_destroy = true
  }
}
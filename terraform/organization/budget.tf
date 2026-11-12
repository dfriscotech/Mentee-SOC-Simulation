variable "budget_primary_email" {
  description = "Primary email subscriber for the 50% budget alert"
  type        = string
  sensitive   = true
}

variable "budget_additional_emails" {
  description = "Additional email subscribers for the higher-threshold alerts"
  type        = list(string)
  sensitive   = true
}

resource "aws_budgets_budget" "monthly_cost" {
  name             = "My Monthly Cost Budget"
  budget_type      = "COST"
  limit_amount     = "35"
  limit_unit       = "USD"
  time_unit        = "MONTHLY"
  billing_view_arn = "arn:aws:billing::577101744776:billingview/primary"
  metrics          = ["UnblendedCost"]

  filter_expression {
    not {
      dimensions {
        key    = "RECORD_TYPE"
        values = ["Credit", "Refund"]
      }
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_primary_email]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    threshold           = 85
    threshold_type      = "PERCENTAGE"
    subscriber_email_addresses = concat(
      [var.budget_primary_email],
      var.budget_additional_emails
    )
  }

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    subscriber_email_addresses = concat(
      [var.budget_primary_email],
      var.budget_additional_emails
    )
  }

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "FORECASTED"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    subscriber_email_addresses = concat(
      [var.budget_primary_email],
      var.budget_additional_emails
    )
  }

  lifecycle {
    prevent_destroy = true
  }
}
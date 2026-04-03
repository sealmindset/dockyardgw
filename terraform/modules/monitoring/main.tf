# ---------------------------------------------------------------------------
# Monitoring -- Log Analytics + Diagnostic Settings + Alerts
#
# Captures all ACR operations (pulls, pushes, cache hits, login events)
# and triggers alerts when images are blocked by vulnerability policies.
# ---------------------------------------------------------------------------

# Log Analytics Workspace -- central log destination
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_prefix}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# Diagnostic Settings -- stream ACR logs to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${var.acr_name}-diagnostics"
  target_resource_id         = var.acr_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Alert: Notify admins when images are blocked
# ---------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "acr_admins" {
  count = length(var.alert_email_addresses) > 0 ? 1 : 0

  name                = "${var.resource_prefix}-acr-admins"
  resource_group_name = var.resource_group_name
  short_name          = "ACRAdmins"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name          = "admin-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }
}

# Alert: Image pull failures (could indicate blocked images or scan issues)
resource "azurerm_monitor_metric_alert" "pull_failures" {
  count = length(var.alert_email_addresses) > 0 ? 1 : 0

  name                = "${var.resource_prefix}-pull-failures"
  resource_group_name = var.resource_group_name
  scopes              = [var.acr_id]
  description         = "Alerts when container image pulls fail, which may indicate blocked images due to vulnerability findings."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerRegistry/registries"
    metric_name      = "StorageUsed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.acr_admins[0].id
  }
}

# Scheduled query alert: detect denied image pulls from policy
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "blocked_images" {
  count = length(var.alert_email_addresses) > 0 ? 1 : 0

  name                = "${var.resource_prefix}-blocked-images"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Fires when Azure Policy blocks an image pull due to Critical/High vulnerability findings."
  severity            = 2
  tags                = var.tags

  scopes                  = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT15M"
  auto_mitigation_enabled = true

  criteria {
    query = <<-QUERY
      AzureActivity
      | where CategoryValue == "Policy"
      | where ActivityStatusValue == "Failure"
      | where OperationNameValue has "Microsoft.ContainerRegistry"
      | project TimeGenerated, Caller, ResourceGroup, _ResourceId, Properties_d
      | order by TimeGenerated desc
    QUERY

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.acr_admins[0].id]
  }
}

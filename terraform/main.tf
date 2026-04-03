provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}

locals {
  resource_prefix = "${var.project_slug}-${var.environment}"
  # ACR names must be alphanumeric only, 5-50 chars
  acr_name = replace("${var.project_slug}${var.environment}", "-", "")

  default_tags = merge(var.tags, {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    owner       = "platform-engineering"
  })
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.default_tags
}

# ---------------------------------------------------------------------------
# ACR Module -- Registry + Proxy Cache
# ---------------------------------------------------------------------------
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = local.acr_name
  acr_sku             = var.acr_sku
  quarantine_enabled  = var.quarantine_enabled
  dockerhub_username  = var.dockerhub_username
  dockerhub_token     = var.dockerhub_token
  tags                = local.default_tags
}

# ---------------------------------------------------------------------------
# Defender Module -- Vulnerability Scanning
# ---------------------------------------------------------------------------
module "defender" {
  source = "./modules/defender"

  resource_group_id = azurerm_resource_group.main.id
  acr_id            = module.acr.acr_id
}

# ---------------------------------------------------------------------------
# Policy Module -- Block Critical/High, Quarantine Medium/Low
# ---------------------------------------------------------------------------
module "policy" {
  source = "./modules/policy"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  acr_id              = module.acr.acr_id
  blocked_severities  = var.blocked_severity_levels
}

# ---------------------------------------------------------------------------
# RBAC Module -- Access Controls
# ---------------------------------------------------------------------------
module "rbac" {
  source = "./modules/rbac"

  acr_id                     = module.acr.acr_id
  acr_admin_group_object_ids = var.acr_admin_group_object_ids
  acr_pull_group_object_ids  = var.acr_pull_group_object_ids
}

# ---------------------------------------------------------------------------
# Monitoring Module -- Log Analytics + Alerts
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  resource_prefix       = local.resource_prefix
  acr_id                = module.acr.acr_id
  acr_name              = module.acr.acr_name
  log_retention_days    = var.log_retention_days
  alert_email_addresses = var.alert_email_addresses
  tags                  = local.default_tags
}

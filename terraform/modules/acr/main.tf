# ---------------------------------------------------------------------------
# Azure Container Registry -- Premium with proxy cache for Docker Hub
# ---------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = false # Use Azure AD auth, not admin credentials

  quarantine_policy_enabled = var.quarantine_enabled
  data_endpoint_enabled     = true # Regional endpoints for faster pulls
  export_policy_enabled     = true
  anonymous_pull_enabled    = false # Require authentication

  retention_policy_in_days      = 30 # Keep untagged manifests for 30 days
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Docker Hub Credential Set -- for authenticated proxy pulls
# Only created when Docker Hub credentials are provided, to avoid rate limits.
# ---------------------------------------------------------------------------

resource "azurerm_container_registry_credential_set" "dockerhub" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  name                  = "dockerhub-credentials"
  container_registry_id = azurerm_container_registry.main.id
  login_server          = "docker.io"

  identity {
    type = "SystemAssigned"
  }

  authentication_credentials {
    username_secret_id = azurerm_key_vault_secret.dockerhub_username[0].versionless_id
    password_secret_id = azurerm_key_vault_secret.dockerhub_token[0].versionless_id
  }
}

# ---------------------------------------------------------------------------
# Key Vault for Docker Hub credentials (only when credentials are provided)
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "acr_secrets" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  name                = "${substr(var.acr_name, 0, 20)}kv"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  key_vault_id = azurerm_key_vault.acr_secrets[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "Delete", "List", "Purge"]
}

resource "azurerm_key_vault_access_policy" "acr" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  key_vault_id = azurerm_key_vault.acr_secrets[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_registry.main.identity[0].principal_id

  secret_permissions = ["Get"]

  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_key_vault_secret" "dockerhub_username" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  name         = "dockerhub-username"
  value        = var.dockerhub_username
  key_vault_id = azurerm_key_vault.acr_secrets[0].id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "dockerhub_token" {
  count = var.dockerhub_username != "" && var.dockerhub_token != "" ? 1 : 0

  name         = "dockerhub-token"
  value        = var.dockerhub_token
  key_vault_id = azurerm_key_vault.acr_secrets[0].id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# ---------------------------------------------------------------------------
# Cache Rules -- map Docker Hub paths to ACR paths
#
# When a user pulls dockyardgw.azurecr.io/docker.io/library/python:3.12,
# ACR fetches from Docker Hub server-side (no Zscaler interference),
# caches the image, and serves it to the user from Azure.
# ---------------------------------------------------------------------------

resource "azurerm_container_registry_cache_rule" "dockerhub_library" {
  name                  = "docker-hub-library"
  container_registry_id = azurerm_container_registry.main.id
  target_repo           = "docker.io/library/*"
  source_repo           = "docker.io/library/*"
  credential_set_id     = length(azurerm_container_registry_credential_set.dockerhub) > 0 ? azurerm_container_registry_credential_set.dockerhub[0].id : null
}

resource "azurerm_container_registry_cache_rule" "dockerhub_community" {
  name                  = "docker-hub-community"
  container_registry_id = azurerm_container_registry.main.id
  target_repo           = "docker.io/*"
  source_repo           = "docker.io/*"
  credential_set_id     = length(azurerm_container_registry_credential_set.dockerhub) > 0 ? azurerm_container_registry_credential_set.dockerhub[0].id : null
}

# Microsoft Container Registry (for .NET, Azure tools, etc.)
resource "azurerm_container_registry_cache_rule" "mcr" {
  name                  = "mcr-microsoft"
  container_registry_id = azurerm_container_registry.main.id
  target_repo           = "mcr.microsoft.com/*"
  source_repo           = "mcr.microsoft.com/*"
}

# GitHub Container Registry (ghcr.io)
resource "azurerm_container_registry_cache_rule" "ghcr" {
  name                  = "github-container-registry"
  container_registry_id = azurerm_container_registry.main.id
  target_repo           = "ghcr.io/*"
  source_repo           = "ghcr.io/*"
}

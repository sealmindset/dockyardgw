# ---------------------------------------------------------------------------
# RBAC -- Role-Based Access Control for the Container Registry
#
# Two tiers of access:
# - AcrPull: Everyone in the company can pull images (read-only)
# - AcrPush: Admins can push images and manage the registry
#
# Access is granted via Azure AD security groups. Pass group object IDs
# through variables -- this avoids hardcoding user identities in Terraform.
# ---------------------------------------------------------------------------

# Grant AcrPull to company-wide groups (everyone can pull images)
resource "azurerm_role_assignment" "acr_pull" {
  for_each = toset(var.acr_pull_group_object_ids)

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = each.value
}

# Grant AcrPush to admin groups (can push and manage images)
resource "azurerm_role_assignment" "acr_push" {
  for_each = toset(var.acr_admin_group_object_ids)

  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = each.value
}

# Grant Contributor on ACR to admin groups (can manage cache rules, policies)
resource "azurerm_role_assignment" "acr_contributor" {
  for_each = toset(var.acr_admin_group_object_ids)

  scope                = var.acr_id
  role_definition_name = "Contributor"
  principal_id         = each.value
}

# ---------------------------------------------------------------------------
# Azure Policy -- Image Vulnerability Enforcement
#
# Two policies working together:
# 1. BLOCK: Deny deployment of images with Critical or High vulnerabilities
#    (RCE, privilege escalation, etc.) -- these never become available.
# 2. AUDIT: Flag images with Medium or Low vulnerabilities for admin review
#    (quarantine via ACR quarantine policy -- admin must approve).
# ---------------------------------------------------------------------------

# Policy: Block images with Critical/High vulnerability findings
resource "azurerm_resource_group_policy_assignment" "block_vulnerable_images" {
  name                 = "block-critical-high-vuln-images"
  display_name         = "Dockyard Gateway: Block Critical/High Vulnerability Images"
  description          = "Prevents use of container images that have Critical or High severity vulnerability findings from Microsoft Defender."
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/13cd7ae3-5bc0-4ac4-a62d-4f7c120b9759"

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
    severity = {
      value = var.blocked_severities
    }
  })
}

# Policy: Audit images with Medium/Low vulnerabilities (quarantine for review)
resource "azurerm_resource_group_policy_assignment" "audit_medium_low_images" {
  name                 = "audit-medium-low-vuln-images"
  display_name         = "Dockyard Gateway: Audit Medium/Low Vulnerability Images"
  description          = "Flags container images with Medium or Low severity vulnerability findings for admin review. These images are quarantined until an admin approves them."
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/13cd7ae3-5bc0-4ac4-a62d-4f7c120b9759"

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
    severity = {
      value = ["Medium", "Low"]
    }
  })
}

# Policy: Ensure only Defender-scanned images can be deployed
resource "azurerm_resource_group_policy_assignment" "require_scan" {
  name                 = "require-vulnerability-scan"
  display_name         = "Dockyard Gateway: Require Vulnerability Scan Before Use"
  description          = "Ensures container images must have completed a Microsoft Defender vulnerability scan before they can be pulled. Unscanned images are blocked."
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0fc39691-5a3f-4e3e-94ee-2e6447309ad9"

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}

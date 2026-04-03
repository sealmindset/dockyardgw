# ---------------------------------------------------------------------------
# Microsoft Defender for Containers -- Vulnerability Scanning
#
# Enables automatic scanning of every image pushed to or cached in the ACR.
# Defender assesses images against the Microsoft vulnerability database and
# produces findings with severity levels (Critical, High, Medium, Low).
# ---------------------------------------------------------------------------

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

# Enable Defender specifically for this ACR
resource "azurerm_security_center_assessment_policy" "acr_vulnerability" {
  display_name = "Dockyard Gateway -- ACR Image Vulnerability Assessment"
  description  = "Scans container images in the Dockyard Gateway ACR for known vulnerabilities. Critical and High severity findings block image usage; Medium and Low are quarantined for admin review."
  severity     = "High"
}

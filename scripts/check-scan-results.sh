#!/usr/bin/env bash
# =============================================================================
# check-scan-results.sh -- View vulnerability scan results for an image
#
# Usage:
#   ./scripts/check-scan-results.sh <image-name>:<tag>
#
# Examples:
#   ./scripts/check-scan-results.sh docker.io/library/python:3.12-slim
#   ./scripts/check-scan-results.sh docker.io/library/node:22-alpine
# =============================================================================

set -euo pipefail

ACR_NAME="${ACR_NAME:-dockyardgwprod}"
IMAGE="${1:-}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image-name>:<tag>"
  echo ""
  echo "Examples:"
  echo "  $0 docker.io/library/python:3.12-slim"
  echo "  $0 docker.io/library/node:22-alpine"
  exit 1
fi

echo "=== Dockyard Gateway -- Scan Results ==="
echo "Registry: ${ACR_NAME}.azurecr.io"
echo "Image:    ${IMAGE}"
echo ""

# Check if the image exists in the registry
echo "Checking image availability..."
if az acr manifest list-metadata "${ACR_NAME}.azurecr.io/${IMAGE%%:*}" --name "${ACR_NAME}" --output table 2>/dev/null; then
  echo ""
else
  echo "Image not found in the registry. It may not have been pulled yet."
  echo ""
  echo "To pull an image through the proxy cache:"
  echo "  docker pull ${ACR_NAME}.azurecr.io/${IMAGE}"
  exit 1
fi

# Query Defender for vulnerability findings
echo "Querying vulnerability scan results..."
echo ""

az security sub-assessment list \
  --assessed-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${ACR_NAME}-prod-rg/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}" \
  --assessment-name "dbd0cb49-b563-45e7-9724-889e799fa648" \
  --query "[?contains(resourceDetails.id, '${IMAGE}')].{Severity:status.severity, CVE:id, Description:displayName, Remediation:remediation}" \
  --output table 2>/dev/null || echo "No scan results available yet. Defender may still be scanning this image."

echo ""
echo "=== Summary ==="
echo "Critical/High findings: Image is BLOCKED (cannot be pulled)"
echo "Medium/Low findings:    Image is QUARANTINED (admin approval needed)"
echo "No findings:            Image is AVAILABLE for everyone"

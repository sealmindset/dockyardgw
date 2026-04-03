#!/usr/bin/env bash
# =============================================================================
# approve-image.sh -- Approve a quarantined image for company-wide use
#
# When Defender finds Medium/Low vulnerabilities, the image is quarantined.
# An admin must review the findings and explicitly approve the image.
#
# Usage:
#   ./scripts/approve-image.sh <image-name>:<tag>
#
# Examples:
#   ./scripts/approve-image.sh docker.io/library/python:3.12-slim
# =============================================================================

set -euo pipefail

ACR_NAME="${ACR_NAME:-dockyardgwprod}"
IMAGE="${1:-}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image-name>:<tag>"
  echo ""
  echo "This approves a quarantined image for company-wide use."
  echo "Only use this after reviewing the vulnerability scan results."
  echo ""
  echo "To check scan results first:"
  echo "  ./scripts/check-scan-results.sh <image-name>:<tag>"
  exit 1
fi

REPO="${IMAGE%%:*}"
TAG="${IMAGE##*:}"

echo "=== Dockyard Gateway -- Approve Quarantined Image ==="
echo "Registry: ${ACR_NAME}.azurecr.io"
echo "Image:    ${REPO}:${TAG}"
echo ""

# Show current scan results first
echo "--- Current Vulnerability Findings ---"
./scripts/check-scan-results.sh "$IMAGE" 2>/dev/null || true
echo ""

# Confirm approval
read -rp "Are you sure you want to approve this image for company-wide use? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Approval cancelled."
  exit 0
fi

# Update the quarantine state (ACR quarantine uses OCI artifact attributes)
echo ""
echo "Approving image..."

# Remove quarantine flag by updating the manifest metadata
az acr repository update \
  --name "${ACR_NAME}" \
  --image "${REPO}:${TAG}" \
  --write-enabled true \
  2>/dev/null

if [[ $? -eq 0 ]]; then
  echo ""
  echo "Image approved! ${REPO}:${TAG} is now available for all users."
  echo ""
  echo "Users can pull it with:"
  echo "  docker pull ${ACR_NAME}.azurecr.io/${REPO}:${TAG}"
else
  echo ""
  echo "Failed to approve image. Make sure you have AcrPush permissions."
  echo "Contact the platform team if this persists."
  exit 1
fi

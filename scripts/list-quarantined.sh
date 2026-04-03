#!/usr/bin/env bash
# =============================================================================
# list-quarantined.sh -- List all quarantined images awaiting admin review
#
# Shows images that have Medium/Low vulnerability findings and need
# explicit admin approval before they can be pulled by regular users.
#
# Usage:
#   ./scripts/list-quarantined.sh
# =============================================================================

set -euo pipefail

ACR_NAME="${ACR_NAME:-dockyardgwprod}"

echo "=== Dockyard Gateway -- Quarantined Images ==="
echo "Registry: ${ACR_NAME}.azurecr.io"
echo ""

# List repositories in the registry
echo "Scanning repositories for quarantined images..."
echo ""

REPOS=$(az acr repository list --name "${ACR_NAME}" --output tsv 2>/dev/null)

if [[ -z "$REPOS" ]]; then
  echo "No repositories found in the registry."
  echo "Images will appear here after the first pull through the proxy cache."
  exit 0
fi

FOUND_QUARANTINED=0

for REPO in $REPOS; do
  # Check for quarantined tags
  TAGS=$(az acr manifest list-metadata "${ACR_NAME}.azurecr.io/${REPO}" \
    --query "[?quarantineState=='Quarantined'].{Tag:tags[0], Digest:digest, LastUpdated:lastUpdateTime}" \
    --output table 2>/dev/null)

  if [[ -n "$TAGS" && "$TAGS" != *"Tag"*"Digest"*"LastUpdated"* || $(echo "$TAGS" | wc -l) -gt 2 ]]; then
    echo "--- ${REPO} ---"
    echo "$TAGS"
    echo ""
    FOUND_QUARANTINED=1
  fi
done

if [[ $FOUND_QUARANTINED -eq 0 ]]; then
  echo "No quarantined images found. All cached images are either:"
  echo "  - Approved and available for use"
  echo "  - Blocked due to Critical/High vulnerabilities"
  echo ""
  echo "To check the scan results for a specific image:"
  echo "  ./scripts/check-scan-results.sh <image-name>:<tag>"
fi

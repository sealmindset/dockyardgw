#!/usr/bin/env bash
# =============================================================================
# bootstrap-tfstate.sh -- Create the Azure Storage Account for Terraform state
#
# Run this ONCE before the first `terraform init` with a remote backend.
# After this completes, uncomment the backend block in terraform/backend.tf.
#
# Usage:
#   ./scripts/bootstrap-tfstate.sh
# =============================================================================

set -euo pipefail

RESOURCE_GROUP="dockyardgw-tfstate-rg"
STORAGE_ACCOUNT="dockyardgwtfstate"
CONTAINER="tfstate"
LOCATION="southcentralus"

echo "=== Bootstrapping Terraform State Backend ==="
echo ""

# Create resource group for state
echo "Creating resource group: ${RESOURCE_GROUP}..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags project="Dockyard Gateway" managed_by=bootstrap \
  --output none

# Create storage account
echo "Creating storage account: ${STORAGE_ACCOUNT}..."
az storage account create \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

# Create blob container
echo "Creating state container: ${CONTAINER}..."
az storage container create \
  --name "${CONTAINER}" \
  --account-name "${STORAGE_ACCOUNT}" \
  --auth-mode login \
  --output none

echo ""
echo "=== State Backend Ready ==="
echo ""
echo "Now uncomment the backend block in terraform/backend.tf and run:"
echo "  cd terraform && terraform init"

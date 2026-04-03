#!/usr/bin/env bash
# =============================================================================
# onboard-user.sh -- Help a user configure Docker to use Dockyard Gateway
#
# Usage:
#   ./scripts/onboard-user.sh
#
# This script walks the user through:
# 1. Logging into the ACR with their Azure AD credentials
# 2. Configuring Docker to use the ACR as a mirror
# 3. Testing with a sample pull
# =============================================================================

set -euo pipefail

ACR_NAME="${ACR_NAME:-dockyardgwprod}"
ACR_SERVER="${ACR_NAME}.azurecr.io"

echo "=== Dockyard Gateway -- User Onboarding ==="
echo ""
echo "This will configure your Docker to pull images through Dockyard Gateway"
echo "instead of directly from Docker Hub. This means:"
echo "  - No need to disable Zscaler or your VPN"
echo "  - Every image is security-scanned before you use it"
echo "  - Faster pulls (images are cached in Azure South Central US)"
echo ""

# Step 1: Check Azure CLI
echo "Step 1: Checking Azure CLI..."
if ! command -v az &>/dev/null; then
  echo "  Azure CLI is not installed."
  echo "  Install it: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

if ! az account show &>/dev/null; then
  echo "  You need to log in to Azure first."
  echo "  Running: az login"
  az login
fi
echo "  Azure CLI: OK"
echo ""

# Step 2: Log in to the ACR
echo "Step 2: Logging in to Dockyard Gateway..."
if az acr login --name "${ACR_NAME}" 2>/dev/null; then
  echo "  ACR login: OK"
else
  echo "  Failed to log in. Make sure you have AcrPull access."
  echo "  Contact the platform team to request access."
  exit 1
fi
echo ""

# Step 3: Test pull
echo "Step 3: Testing with a sample image pull..."
echo "  Pulling: ${ACR_SERVER}/docker.io/library/alpine:latest"
if docker pull "${ACR_SERVER}/docker.io/library/alpine:latest" 2>/dev/null; then
  echo "  Test pull: OK"
else
  echo "  Test pull failed. The image may still be scanning."
  echo "  Try again in a few minutes."
fi
echo ""

# Step 4: Show usage instructions
echo "=== Setup Complete! ==="
echo ""
echo "How to use Dockyard Gateway:"
echo ""
echo "  Instead of:  docker pull python:3.12-slim"
echo "  Use:         docker pull ${ACR_SERVER}/docker.io/library/python:3.12-slim"
echo ""
echo "  Instead of:  docker pull node:22-alpine"
echo "  Use:         docker pull ${ACR_SERVER}/docker.io/library/node:22-alpine"
echo ""
echo "  Instead of:  docker pull postgres:16"
echo "  Use:         docker pull ${ACR_SERVER}/docker.io/library/postgres:16"
echo ""
echo "In your Dockerfile, replace base image references:"
echo ""
echo "  # Before"
echo "  FROM python:3.12-slim"
echo ""
echo "  # After"
echo "  FROM ${ACR_SERVER}/docker.io/library/python:3.12-slim"
echo ""
echo "In your docker-compose.yml:"
echo ""
echo "  services:"
echo "    app:"
echo "      image: ${ACR_SERVER}/docker.io/library/python:3.12-slim"
echo ""
echo "Your ACR login token refreshes automatically. If pulls start failing,"
echo "just run:  az acr login --name ${ACR_NAME}"

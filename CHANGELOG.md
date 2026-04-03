# Changelog

All notable changes to Dockyard Gateway will be documented in this file.

## [1.0.0] - 2026-04-02

### Added
- Azure Container Registry (Premium) with proxy cache for Docker Hub, MCR, and GHCR
- Microsoft Defender for Containers integration for automatic vulnerability scanning
- Azure Policy enforcement: Critical/High vulnerabilities blocked, Medium/Low quarantined
- RBAC via Azure AD groups (AcrPull for all users, AcrPush for admins)
- Log Analytics workspace with diagnostic settings for all registry operations
- Alert rules for blocked image pulls
- Admin scripts: check-scan-results, approve-image, list-quarantined, onboard-user
- Bootstrap script for Terraform remote state backend
- Terraform modular architecture (acr, defender, monitoring, policy, rbac)
- Key Vault integration for Docker Hub credentials (optional, avoids rate limits)

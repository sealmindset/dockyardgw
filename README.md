# Dockyard Gateway

A company-wide Azure Container Registry that acts as a secure proxy cache for Docker Hub. Users pull images from Dockyard Gateway instead of Docker Hub directly -- no need to disable Zscaler or fight with corporate proxies. Every image is automatically scanned for vulnerabilities before it becomes available.

## Features

- **Proxy cache for Docker Hub** -- pull any Docker Hub image through the ACR; fetches happen server-side in Azure, bypassing Zscaler/SSL-inspecting proxies entirely
- **Proxy cache for MCR and GHCR** -- also caches Microsoft Container Registry and GitHub Container Registry images
- **Automatic vulnerability scanning** -- Microsoft Defender for Containers scans every image that enters the registry
- **Smart enforcement** -- Critical/High vulnerabilities (RCE, privilege escalation, etc.) are blocked; Medium/Low are quarantined for admin review
- **Company-wide access** -- everyone can pull images; only admins can push or approve quarantined images
- **Monitoring and alerts** -- Log Analytics captures all registry activity; admins are notified when images are blocked
- **Infrastructure as Code** -- everything is defined in Terraform, versioned and repeatable

## How It Works

```
User runs: docker pull dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim

  1. Docker asks Dockyard Gateway (ACR) for the image
  2. ACR checks its cache -- if the image is already cached, serves it immediately
  3. If not cached, ACR fetches the image from Docker Hub server-side (in Azure)
     (This step happens entirely in Azure's network -- Zscaler never sees it)
  4. Microsoft Defender scans the image for vulnerabilities
  5. Based on scan results:
     - No findings        --> Image available immediately
     - Medium/Low vulns   --> Image quarantined, admin approval required
     - Critical/High vulns --> Image blocked, cannot be pulled
  6. User receives the image (or an error if blocked)
```

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- Azure subscription with permissions to create resources
- Azure AD group object IDs for admin and pull groups

## Getting Started

### 1. Clone the repository

```bash
git clone <REPO_URL>
cd dockyardgw
```

### 2. Bootstrap the Terraform state backend (first time only)

```bash
az login
./scripts/bootstrap-tfstate.sh
```

Then uncomment the backend block in `terraform/backend.tf`.

### 3. Configure your variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and fill in:
- `acr_admin_group_object_ids` -- Azure AD group(s) for registry admins
- `acr_pull_group_object_ids` -- Azure AD group(s) for all users who need to pull images
- `alert_email_addresses` -- who gets notified when images are blocked
- (Optional) `dockerhub_username` and `dockerhub_token` -- avoids Docker Hub rate limits

### 4. Deploy

```bash
cd terraform
terraform init
terraform plan    # Review what will be created
terraform apply   # Create the resources
```

### 5. Onboard users

Share the onboarding script with your team:

```bash
./scripts/onboard-user.sh
```

Or give them the manual steps:

```bash
# Log in to the registry
az acr login --name dockyardgwprod

# Pull images through the gateway
docker pull dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim
```

## Pulling Images

Instead of pulling directly from Docker Hub, prefix the image with the ACR login server:

| Before (Docker Hub direct) | After (Dockyard Gateway) |
|---|---|
| `python:3.12-slim` | `dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim` |
| `node:22-alpine` | `dockyardgwprod.azurecr.io/docker.io/library/node:22-alpine` |
| `postgres:16` | `dockyardgwprod.azurecr.io/docker.io/library/postgres:16` |
| `nginx:alpine` | `dockyardgwprod.azurecr.io/docker.io/library/nginx:alpine` |
| `bitnami/redis:latest` | `dockyardgwprod.azurecr.io/docker.io/bitnami/redis:latest` |

In Dockerfiles:
```dockerfile
# Before
FROM python:3.12-slim

# After
FROM dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim
```

## Admin Guide

### Check scan results for an image

```bash
./scripts/check-scan-results.sh docker.io/library/python:3.12-slim
```

### List quarantined images (awaiting approval)

```bash
./scripts/list-quarantined.sh
```

### Approve a quarantined image

After reviewing the scan results, approve an image for company-wide use:

```bash
./scripts/approve-image.sh docker.io/library/python:3.12-slim
```

### Vulnerability policy summary

| Severity | Action | Who can override |
|----------|--------|-----------------|
| Critical | **Blocked** -- image cannot be pulled by anyone | No override -- use a patched version |
| High | **Blocked** -- image cannot be pulled by anyone | No override -- use a patched version |
| Medium | **Quarantined** -- available after admin approval | ACR admins via `approve-image.sh` |
| Low | **Quarantined** -- available after admin approval | ACR admins via `approve-image.sh` |
| None | **Available** -- pulls immediately | N/A |

## Project Structure

```
dockyardgw/
├── terraform/
│   ├── main.tf                  # Root module -- wires everything together
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values (ACR URL, login commands)
│   ├── versions.tf              # Provider version constraints
│   ├── backend.tf               # Remote state configuration
│   ├── terraform.tfvars.example # Example variable values
│   └── modules/
│       ├── acr/                 # Container Registry + proxy cache rules
│       ├── defender/            # Microsoft Defender for Containers
│       ├── monitoring/          # Log Analytics + alerts
│       ├── policy/              # Azure Policy (block/quarantine)
│       └── rbac/                # Role assignments (pull/push/admin)
├── scripts/
│   ├── bootstrap-tfstate.sh     # One-time state backend setup
│   ├── onboard-user.sh          # User onboarding walkthrough
│   ├── check-scan-results.sh    # View vulnerability findings
│   ├── list-quarantined.sh      # List quarantined images
│   └── approve-image.sh         # Approve a quarantined image
├── docs/
│   └── runbook.md               # Operational runbook
├── CHANGELOG.md
├── TODO.md
└── README.md
```

## Access Control

| Role | Who | Permissions |
|------|-----|-------------|
| AcrPull | All company users | Pull images from the registry |
| AcrPush | Platform admins | Push images, manage tags |
| Contributor | Platform admins | Manage cache rules, policies, settings |

Access is granted via Azure AD security groups. Add users to the appropriate group in Azure AD -- no per-user configuration needed.

## Monitoring

- **Log Analytics** captures all registry operations (pulls, pushes, logins, cache hits)
- **Alerts** fire when Azure Policy blocks an image pull due to vulnerability findings
- **Azure Portal** > Container Registry > Vulnerability assessment shows scan results

### Useful KQL queries

```kusto
// Recent pull events
ContainerRegistryRepositoryEvents
| where OperationName == "Pull"
| project TimeGenerated, Repository, Tag, CallerIpAddress, Identity
| order by TimeGenerated desc

// Failed pulls (potentially blocked by policy)
ContainerRegistryRepositoryEvents
| where OperationName == "Pull" and ResultType != "Success"
| project TimeGenerated, Repository, Tag, ResultType, ResultDescription
| order by TimeGenerated desc
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ACR_NAME` | Registry name (used by admin scripts) | Yes (default: `dockyardgwprod`) |

## License

Internal use only.

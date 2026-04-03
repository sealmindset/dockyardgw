# Dockyard Gateway -- What's Needed
> Generated: 2026-04-02
> Status: Needs Configuration Before Deploy

## What's Done

- [x] Terraform modules built and validated (acr, defender, monitoring, policy, rbac)
- [x] ACR Premium with proxy cache for Docker Hub, MCR, and GHCR
- [x] Microsoft Defender for Containers integration
- [x] Azure Policy: Critical/High blocked, Medium/Low quarantined
- [x] RBAC via Azure AD groups (AcrPull for all, AcrPush for admins)
- [x] Log Analytics + diagnostic settings + alert rules
- [x] Admin scripts (onboard-user, check-scan-results, approve-image, list-quarantined)
- [x] Bootstrap script for Terraform remote state
- [x] Operational runbook
- [x] Code committed and pushed to GitHub (sealmindset + SleepNumberInc)
- [x] Azure CLI authenticated (rob.vance@sleepnumber.com)
- [x] Terraform v1.12.2 installed
- [x] Current subscription: sn-openai-dev-01

## Before First Deploy

### 1. Pick the right Azure subscription
You're currently on `sn-openai-dev-01`. Dockyard Gateway is company-wide infrastructure,
so it likely belongs in a platform/shared-services subscription.

- **You can do this now:**
  ```bash
  # List subscriptions you have access to
  az account list --output table

  # Switch to the right one
  az account set --subscription "<subscription-name-or-id>"
  ```

- **If you don't have a subscription for this:** submit a request to your cloud team
  for a shared-services or platform-engineering subscription.

### 2. Get Azure AD group object IDs (NEEDS LOOKUP)
The RBAC module needs two Azure AD group IDs:

| Group | Purpose | Where to Find |
|-------|---------|---------------|
| **Admin group** | Platform engineers who manage the registry (push, approve images) | Azure Portal > Entra ID > Groups > search for your platform team group > copy Object ID |
| **All-users group** | Everyone who can pull images (typically a company-wide group) | Azure Portal > Entra ID > Groups > search for "All Employees" or equivalent > copy Object ID |

- **You can do this now** if you have Entra ID read access:
  ```bash
  # Search for groups by name
  az ad group list --display-name "Platform" --output table
  az ad group list --display-name "All Employees" --output table
  ```

- **If you can't see groups:** ask your Identity/IAM team for the object IDs.

### 3. Create terraform.tfvars (YOU CAN DO THIS NOW)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (see below)
```

Fill in these values:

| Variable | What to Put | Required? |
|----------|-------------|-----------|
| `acr_admin_group_object_ids` | Object ID(s) from step 2 | Yes |
| `acr_pull_group_object_ids` | Object ID(s) from step 2 | Yes |
| `alert_email_addresses` | Team email for blocked-image alerts | Recommended |
| `dockerhub_username` | Docker Hub username (avoids rate limits) | Optional |
| `dockerhub_token` | Docker Hub PAT | Optional |
| `tags.cost_center` | Your team's cost center code | If required by policy |

### 4. Set up remote state (RECOMMENDED)
Stores Terraform state in Azure so your team can collaborate.

- **You can do this now:**
  ```bash
  # Make sure you're on the right subscription first (step 1)
  ./scripts/bootstrap-tfstate.sh

  # Then uncomment the backend block in terraform/backend.tf
  # Then re-init:
  cd terraform && terraform init
  ```

### 5. Plan and apply (YOU CAN DO THIS after steps 1-3)
```bash
cd terraform
terraform plan          # Review what will be created
terraform apply         # Deploy (type "yes" to confirm)
```

## After Deploy

### 6. Verify it works (YOU CAN DO THIS)
- [ ] Test proxy cache: `docker pull <acr-name>.azurecr.io/dockerhub/library/python:3.12-slim`
- [ ] Check Defender: Azure Portal > Defender for Cloud > Recommendations
- [ ] Run `./scripts/check-scan-results.sh` on a pulled image
- [ ] Test quarantine: find an image with Medium vulns, approve with `./scripts/approve-image.sh`

### 7. Onboard the team (YOU CAN DO THIS)
- [ ] Run `./scripts/onboard-user.sh` for a test user
- [ ] Share the operational runbook (`docs/runbook.md`) with the team
- [ ] Distribute Docker config instructions (ACR login, proxy cache URLs)

## Tickets / Requests Needed

| What | Who to Ask | Request Template |
|------|-----------|-----------------|
| Azure subscription (if current one isn't right) | Cloud/Platform team | "Need a subscription for shared container registry infrastructure (Dockyard Gateway). Resources: ACR Premium, Log Analytics, Key Vault." |
| Azure AD group object IDs (if you can't look them up) | Identity/IAM team | "Need the Object ID for: (1) Platform Engineering admin group, (2) company-wide All Employees group. For ACR RBAC role assignments." |
| Docker Hub PAT (optional, avoids rate limits) | Self-service | Create at https://hub.docker.com/settings/security -- "Read-only" scope is sufficient |
| Cost center tag (if required) | Your manager | "What cost center should Dockyard Gateway bill to?" |

## Secrets & Environment Variables

**Local:** `terraform.tfvars` (gitignored) holds all configuration.
**Production:** Terraform state in Azure Storage (encrypted at rest). Docker Hub credentials (if used) stored in Azure Key Vault by the ACR module.

| Variable | Purpose | Where to Get It | Status |
|----------|---------|----------------|--------|
| `acr_admin_group_object_ids` | RBAC for admins | Entra ID > Groups | [ ] Needed |
| `acr_pull_group_object_ids` | RBAC for all users | Entra ID > Groups | [ ] Needed |
| `alert_email_addresses` | Blocked-image alerts | Your team's email | [ ] Needed |
| `dockerhub_username` | Avoid Docker Hub rate limits | hub.docker.com | [ ] Optional |
| `dockerhub_token` | Avoid Docker Hub rate limits | hub.docker.com/settings/security | [ ] Optional |

## Suggested Order of Operations

1. **Now:** Look up Azure AD group object IDs (or submit ticket if you can't)
2. **Now:** Decide which subscription to deploy in (switch if needed)
3. **Now:** Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values
4. **Now (optional):** Run `bootstrap-tfstate.sh` for remote state
5. **When tfvars is ready:** `terraform plan` then `terraform apply`
6. **After deploy:** Test proxy cache pull, verify Defender, test quarantine flow
7. **After verified:** Onboard the team, distribute runbook
8. **When ready to share:** Run `/ship-it` to create a PR for team review

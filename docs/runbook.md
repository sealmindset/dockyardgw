# Dockyard Gateway -- Operational Runbook

## Common Scenarios

### User can't pull an image

**Symptom:** `docker pull dockyardgwprod.azurecr.io/docker.io/library/python:3.12` fails.

**Diagnosis steps:**

1. **Check if they're logged in:**
   ```bash
   az acr login --name dockyardgwprod
   ```

2. **Check if they have AcrPull access:**
   - Azure Portal > Container Registry > Access Control (IAM)
   - Verify their group has AcrPull role

3. **Check if the image is quarantined:**
   ```bash
   ./scripts/check-scan-results.sh docker.io/library/python:3.12
   ```

4. **Check if the image is blocked:**
   - If scan shows Critical/High findings, the image is blocked by policy
   - Recommend a different tag (e.g., `python:3.12-slim` instead of `python:3.12`)

### Image is quarantined -- admin approval needed

1. Review the scan findings:
   ```bash
   ./scripts/check-scan-results.sh docker.io/library/python:3.12-slim
   ```

2. If the findings are acceptable (Medium/Low only, no RCE):
   ```bash
   ./scripts/approve-image.sh docker.io/library/python:3.12-slim
   ```

3. Notify the requesting user that the image is now available.

### Defender isn't scanning images

**Symptom:** Images are available immediately without scan results.

1. Verify Defender for Containers is enabled:
   - Azure Portal > Defender for Cloud > Environment Settings > Select subscription
   - Containers should show "On"

2. Check if the ACR is in a supported region (South Central US is supported)

3. New images may take 5-15 minutes for the first scan. Check back shortly.

### ACR login token expired

ACR tokens expire after a few hours. Users just need to re-authenticate:

```bash
az acr login --name dockyardgwprod
```

This is automatic if they're using `az acr login` (refreshes the Docker credential helper).

### Docker Hub rate limiting

If you see "too many requests" errors from Docker Hub through the cache:

1. Check if Docker Hub credentials are configured:
   ```bash
   az keyvault secret show --vault-name dockyardgwprodkv --name dockerhub-username
   ```

2. If not configured, add Docker Hub credentials to `terraform.tfvars` and re-apply:
   ```hcl
   dockerhub_username = "your-username"
   dockerhub_token    = "dckr_pat_xxxx"
   ```

## Monitoring

### View logs in Log Analytics

Azure Portal > Log Analytics Workspace > Logs

**Recent pull activity:**
```kusto
ContainerRegistryRepositoryEvents
| where OperationName == "Pull"
| project TimeGenerated, Repository, Tag, CallerIpAddress, Identity
| order by TimeGenerated desc
| take 50
```

**Failed operations (last 24h):**
```kusto
ContainerRegistryRepositoryEvents
| where TimeGenerated > ago(24h)
| where ResultType != "Success"
| summarize count() by OperationName, ResultType, Repository
```

**Cache hit rate:**
```kusto
ContainerRegistryRepositoryEvents
| where TimeGenerated > ago(7d)
| where OperationName == "Pull"
| extend CacheHit = iif(ResultDescription has "cache", true, false)
| summarize CacheHits=countif(CacheHit), Total=count()
| extend HitRate = round(100.0 * CacheHits / Total, 1)
```

## Emergency Procedures

### Disable quarantine (allow all images temporarily)

If quarantine is blocking critical work:

1. In `terraform.tfvars`, set:
   ```hcl
   quarantine_enabled = false
   ```

2. Apply:
   ```bash
   cd terraform && terraform apply
   ```

3. **Re-enable quarantine** as soon as the emergency is resolved.

### Disable vulnerability policy (allow all severities temporarily)

1. Azure Portal > Policy > Assignments
2. Find "Dockyard Gateway: Block Critical/High Vulnerability Images"
3. Click "..." > Disable assignment
4. **Re-enable** as soon as the emergency is resolved.

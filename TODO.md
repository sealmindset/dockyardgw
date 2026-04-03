# TODO

## Before First Deploy
- [ ] Get Azure AD group object IDs for admin and all-users groups
- [ ] Fill in `terraform.tfvars` with group IDs and alert email addresses
- [ ] (Optional) Create Docker Hub personal access token for authenticated pulls
- [ ] Run `bootstrap-tfstate.sh` and uncomment the backend block in `backend.tf`
- [ ] Run `terraform plan` to review, then `terraform apply`

## After Deploy
- [ ] Test user onboarding with `onboard-user.sh`
- [ ] Verify proxy cache pulls work (pull a common image like `python:3.12-slim`)
- [ ] Verify Defender scanning activates (check Azure Portal > Defender > Recommendations)
- [ ] Test quarantine flow (find an image with Medium vulns, approve it)
- [ ] Distribute onboarding instructions to the team

## Future Enhancements
- [ ] Add cache rules for additional registries (Quay.io, ECR Public, etc.)
- [ ] Set up geo-replication if teams are in multiple regions
- [ ] Add webhook notifications for quarantined images (Slack/Teams integration)
- [ ] Create a self-service portal for image approval requests
- [ ] Add automated approval for images that only have Low severity findings
- [ ] Configure network rules to restrict ACR access to corporate IP ranges
- [ ] Add content trust / image signing for approved images
- [ ] Set up Azure DevOps or GitHub Actions pipeline for Terraform changes

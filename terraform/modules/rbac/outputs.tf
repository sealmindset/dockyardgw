output "pull_role_assignments" {
  description = "Number of AcrPull role assignments created"
  value       = length(azurerm_role_assignment.acr_pull)
}

output "push_role_assignments" {
  description = "Number of AcrPush role assignments created"
  value       = length(azurerm_role_assignment.acr_push)
}

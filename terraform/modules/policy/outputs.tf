output "block_policy_id" {
  description = "Assignment ID of the Critical/High blocking policy"
  value       = azurerm_resource_group_policy_assignment.block_vulnerable_images.id
}

output "audit_policy_id" {
  description = "Assignment ID of the Medium/Low audit policy"
  value       = azurerm_resource_group_policy_assignment.audit_medium_low_images.id
}

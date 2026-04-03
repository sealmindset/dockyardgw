output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server URL for the ACR (use this in Docker commands)"
  value       = module.acr.acr_login_server
}

output "acr_id" {
  description = "Resource ID of the ACR"
  value       = module.acr.acr_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = module.monitoring.workspace_id
}

output "docker_pull_example" {
  description = "Example Docker pull command using the proxy cache"
  value       = "docker pull ${module.acr.acr_login_server}/docker.io/library/python:3.12-slim"
}

output "docker_login_command" {
  description = "Command to authenticate Docker with the ACR"
  value       = "az acr login --name ${module.acr.acr_name}"
}

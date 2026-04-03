variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group"
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the ACR"
  type        = string
}

variable "blocked_severities" {
  description = "Severity levels that are blocked entirely (denied)"
  type        = list(string)
  default     = ["Critical", "High"]
}

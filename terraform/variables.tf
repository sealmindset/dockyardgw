variable "project_name" {
  description = "Human-readable project name"
  type        = string
  default     = "Dockyard Gateway"
}

variable "project_slug" {
  description = "Short identifier used in resource names (no spaces, lowercase)"
  type        = string
  default     = "dockyardgw"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "southcentralus"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "acr_sku" {
  description = "ACR SKU tier -- Premium is required for cache rules and content trust"
  type        = string
  default     = "Premium"

  validation {
    condition     = var.acr_sku == "Premium"
    error_message = "Premium SKU is required for proxy cache, content trust, and advanced security features."
  }
}

variable "dockerhub_username" {
  description = "Docker Hub username for authenticated pulls (avoids rate limits). Leave empty for anonymous."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_token" {
  description = "Docker Hub personal access token for authenticated pulls. Leave empty for anonymous."
  type        = string
  default     = ""
  sensitive   = true
}

variable "acr_admin_group_object_ids" {
  description = "Azure AD group object IDs for ACR administrators (AcrPush + image approval)"
  type        = list(string)
  default     = []
}

variable "acr_pull_group_object_ids" {
  description = "Azure AD group object IDs for users who can pull images (typically all-company group)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 90
}

variable "alert_email_addresses" {
  description = "Email addresses to receive alerts when images are blocked"
  type        = list(string)
  default     = []
}

variable "quarantine_enabled" {
  description = "Enable ACR quarantine policy for scanned images"
  type        = bool
  default     = true
}

variable "blocked_severity_levels" {
  description = "Vulnerability severity levels that will be blocked entirely"
  type        = list(string)
  default     = ["Critical", "High"]
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

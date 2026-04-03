variable "acr_id" {
  description = "Resource ID of the ACR"
  type        = string
}

variable "acr_admin_group_object_ids" {
  description = "Azure AD group object IDs for ACR administrators"
  type        = list(string)
  default     = []
}

variable "acr_pull_group_object_ids" {
  description = "Azure AD group object IDs for users who can pull images"
  type        = list(string)
  default     = []
}

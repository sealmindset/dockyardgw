variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "acr_sku" {
  type    = string
  default = "Premium"
}

variable "quarantine_enabled" {
  type    = bool
  default = true
}

variable "dockerhub_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "dockerhub_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

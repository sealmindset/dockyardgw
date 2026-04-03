variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_prefix" {
  type = string
}

variable "acr_id" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "alert_email_addresses" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

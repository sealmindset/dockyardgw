# Remote state backend -- uncomment and configure when ready for team use.
# The storage account must be created manually or via a bootstrap script before
# running `terraform init` with this backend.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "dockyardgw-tfstate-rg"
#     storage_account_name = "dockyardgwtfstate"
#     container_name       = "tfstate"
#     key                  = "dockyardgw.tfstate"
#   }
# }

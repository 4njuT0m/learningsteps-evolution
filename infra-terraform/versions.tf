terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }

  # State is kept in Azure Storage (created by hand in Phase 3).
  # Access uses my Entra ID sign-in; the storage account has no keys.
  backend "azurerm" {
    resource_group_name  = "rg-lsevo-tfstate"
    storage_account_name = "stlsevotfd27660"
    container_name       = "tfstate"
    key                  = "lsevo.tfstate"
    use_azuread_auth     = true
  }
}

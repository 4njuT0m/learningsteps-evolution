# The subscription comes from the ARM_SUBSCRIPTION_ID environment variable,
# so no subscription ID is written in the code.
provider "azurerm" {
  features {
    key_vault {
      # Purge protection is on, so a deleted vault or secret cannot be purged anyway
      purge_soft_delete_on_destroy          = false
      purge_soft_deleted_secrets_on_destroy = false
    }
  }
}

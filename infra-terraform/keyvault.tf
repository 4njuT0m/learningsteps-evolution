resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.prefix}-${local.suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Only my IP and the AKS subnet can reach the vault
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = [var.operator_ip]
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }

  tags = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }

  # Create the vault only after AKS has finished joining its subnet.
  # During the rebuild the subnet was still "Updating" and the vault creation failed.
  depends_on = [azurerm_kubernetes_cluster.main]
}


# Me: write the secrets with Terraform
resource "azurerm_role_assignment" "me_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# New role assignments take a moment to become active
resource "time_sleep" "wait_for_kv_role" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.me_kv_officer]
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = local.database_url
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_for_kv_role]
}

resource "azurerm_key_vault_secret" "database_admin_url" {
  name         = "database-admin-url"
  value        = local.database_admin_url
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_for_kv_role]
}

resource "azurerm_key_vault_secret" "database_app_password" {
  name         = "database-app-password"
  value        = random_password.db_app.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_for_kv_role]
}

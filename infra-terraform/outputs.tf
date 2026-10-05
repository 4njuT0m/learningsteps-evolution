output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "api_identity_client_id" {
  value = azurerm_user_assigned_identity.api.client_id
}

output "dbinit_identity_client_id" {
  value = azurerm_user_assigned_identity.dbinit.client_id
}

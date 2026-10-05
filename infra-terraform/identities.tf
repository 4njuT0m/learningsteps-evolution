# Each Kubernetes service account gets its own Azure identity,
# and each identity can read only the secrets it needs.

# --- API pods: read database-url only ---
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.prefix}-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_federated_identity_credential" "api" {
  name                      = "fic-${var.prefix}-api"
  user_assigned_identity_id = azurerm_user_assigned_identity.api.id
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.k8s_namespace}:${var.api_service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "api_read_database_url" {
  scope                = azurerm_key_vault_secret.database_url.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
  principal_type       = "ServicePrincipal"
}

# --- Database setup job: admin URL and the app user's password ---
resource "azurerm_user_assigned_identity" "dbinit" {
  name                = "id-${var.prefix}-dbinit"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_federated_identity_credential" "dbinit" {
  name                      = "fic-${var.prefix}-dbinit"
  user_assigned_identity_id = azurerm_user_assigned_identity.dbinit.id
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.k8s_namespace}:${var.dbinit_service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "dbinit_read_admin_url" {
  scope                = azurerm_key_vault_secret.database_admin_url.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.dbinit.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "dbinit_read_app_password" {
  scope                = azurerm_key_vault_secret.database_app_password.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.dbinit.principal_id
  principal_type       = "ServicePrincipal"
}

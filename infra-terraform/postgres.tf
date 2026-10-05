# Passwords contain only letters and numbers, so they can be used in a URL as they are
resource "random_password" "db_admin" {
  length  = 32
  special = false
}

resource "random_password" "db_app" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${var.prefix}-${local.suffix}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  sku_name                      = var.postgres_sku
  storage_mb                    = 32768
  backup_retention_days         = 7
  administrator_login           = "lsadmin"
  administrator_password        = random_password.db_admin.result
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.db.id
  public_network_access_enabled = false
  tags                          = local.tags

  lifecycle {
    # Azure picks the zone; do not try to move the server later.
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone.
    ignore_changes = [zone, tags["created-on"]]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_postgresql_flexible_server_database" "journal" {
  name      = "learning_journal"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

locals {
  db_host = azurerm_postgresql_flexible_server.main.fqdn
  db_name = azurerm_postgresql_flexible_server_database.journal.name

  # The app connects as its own user (created by the setup job), not as the admin
  database_url       = "postgresql://lsapp:${random_password.db_app.result}@${local.db_host}:5432/${local.db_name}?sslmode=require"
  database_admin_url = "postgresql://lsadmin:${random_password.db_admin.result}@${local.db_host}:5432/${local.db_name}?sslmode=require"
}

# Server logging for connections and checkpoints, and throttling of repeated failed logins.
# The server accepts one change at a time, so these run one after another.
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_database.journal]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.log_connections]
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.log_checkpoints]
}

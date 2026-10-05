resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

# AKS nodes. The Key Vault service endpoint lets the nodes reach the vault
# even though the vault only accepts traffic from listed networks.
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.prefix}-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.30.1.0/24"]

  service_endpoint {
    service = "Microsoft.KeyVault"
  }
}

# PostgreSQL only. The subnet is delegated to the Flexible Server service.
resource "azurerm_subnet" "db" {
  name                 = "snet-${var.prefix}-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.30.2.0/24"]

  # Azure adds this endpoint for PostgreSQL Flexible Server; it is listed here so Terraform does not remove it
  service_endpoint {
    service = "Microsoft.Storage"
  }

  delegation {
    name = "postgres-flexible"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private DNS, so the database name resolves to its private IP inside the VNet
resource "azurerm_private_dns_zone" "db" {
  name                = "${var.prefix}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                = "link-${var.prefix}-db"
  private_dns_zone_id = azurerm_private_dns_zone.db.id
  virtual_network_id  = azurerm_virtual_network.main.id
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

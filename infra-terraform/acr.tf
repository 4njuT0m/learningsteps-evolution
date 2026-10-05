resource "azurerm_container_registry" "main" {
  name                = "acr${var.prefix}${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

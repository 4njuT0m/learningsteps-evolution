data "azurerm_client_config" "current" {}

# Short random part for names that must be unique across Azure
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  tags = {
    project = "learningsteps-evolution"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

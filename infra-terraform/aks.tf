# Identity of the AKS control plane. It is created before the cluster so it can
# get its role on the AKS subnet first.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_role_assignment" "aks_subnet" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.prefix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  # Sign-in to the cluster only with Entra ID; Azure roles decide what is allowed
  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Only my IP can reach the Kubernetes API from the internet
  api_server_access_profile {
    authorized_ip_ranges = ["${var.operator_ip}/32"]
  }

  # Pods get Azure identities through their service account (workload identity)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # CSI driver that mounts Key Vault secrets into pods
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    node_count                  = var.node_count
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_size_gb             = 64
    temporary_name_for_rotation = "systemtmp"

    # One extra node during upgrades (2 more vCPUs)
    upgrade_settings {
      max_surge = "1"
    }
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Azure CNI overlay: nodes use the subnet, pods get addresses from a separate range.
  # Cilium enforces Kubernetes network policies.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.20.0.0/16"
    dns_service_ip      = "172.20.0.10"
  }

  tags = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }

  depends_on = [azurerm_role_assignment.aks_subnet]
}

# The nodes may pull images from the registry, nothing more
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

# Me: full access inside the cluster through Entra ID
resource "azurerm_role_assignment" "me_aks_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

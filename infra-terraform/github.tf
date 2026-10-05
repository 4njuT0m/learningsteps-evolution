# Identity for the GitHub Actions pipeline. It has no password or secret:
# GitHub proves who it is with a short-lived OIDC token.
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.prefix}-github"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  lifecycle {
    # My subscription adds a created-on tag to every new resource; Terraform leaves it alone
    ignore_changes = [tags["created-on"]]
  }
}

# Only workflow runs on the main branch of my repository can use this identity.
# New GitHub repositories put the numeric owner and repository IDs into the subject.
resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "fic-${var.prefix}-github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/main"
  audience                  = ["api://AzureADTokenExchange"]
}

# Push images to the registry
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

# The API server only accepts my IP, so the pipeline deploys with "az aks command invoke".
# That runs kubectl inside the cluster through Azure. This role allows only that.
resource "azurerm_role_definition" "aks_run_command" {
  name        = "${var.prefix}-aks-run-command-${local.suffix}"
  scope       = azurerm_resource_group.main.id
  description = "Read the AKS cluster and run commands in it with az aks command invoke"

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/runcommand/action",
      "Microsoft.ContainerService/managedClusters/commandResults/read",
    ]
  }

  assignable_scopes = [azurerm_resource_group.main.id]
}

resource "azurerm_role_assignment" "github_aks_run_command" {
  scope              = azurerm_kubernetes_cluster.main.id
  role_definition_id = azurerm_role_definition.aks_run_command.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.github.principal_id
  principal_type     = "ServicePrincipal"
}

# Inside the cluster: change objects in the lsevo namespace only
resource "azurerm_role_assignment" "github_aks_namespace_writer" {
  scope                = "${azurerm_kubernetes_cluster.main.id}/namespaces/${var.k8s_namespace}"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

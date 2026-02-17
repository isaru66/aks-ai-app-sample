# Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = "uami-aks-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.resource_suffix}"
  kubernetes_version  = var.kubernetes_version

  # Private cluster configuration
  private_cluster_enabled = var.enable_private_cluster

  # Workload identity and OIDC issuer (required for Envoy Gateway)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Default node pool
  default_node_pool {
    name                 = "system"
    node_count           = var.enable_autoscaling ? null : var.node_count
    vm_size              = var.node_size
    vnet_subnet_id       = var.vnet_subnet_id
    auto_scaling_enabled = var.enable_autoscaling
    min_count            = var.enable_autoscaling ? var.min_node_count : null
    max_count            = var.enable_autoscaling ? var.max_node_count : null
    
    # Ephemeral OS disk for better performance and cost savings
    os_disk_type = "Ephemeral"
    
    type = "VirtualMachineScaleSets"

    # Node labels for system workloads
    node_labels = {
      "workload" = "system"
    }

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Managed identity configuration
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Network profile (Azure CNI Overlay - no pod IPs from VNet)
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
    service_cidr        = "10.10.0.0/16"
    dns_service_ip      = "10.10.0.10"
    pod_cidr            = "10.244.0.0/16"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = []
  }

  # Monitoring with Container Insights
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Maintenance window (production only)
  dynamic "maintenance_window" {
    for_each = var.environment == "production" ? [1] : []
    content {
      allowed {
        day   = "Sunday"
        hours = [0, 1, 2, 3]
      }
    }
  }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = true
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      microsoft_defender
    ]
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_size
  vnet_subnet_id        = var.vnet_subnet_id
  auto_scaling_enabled  = var.enable_autoscaling
  node_count            = var.enable_autoscaling ? null : var.node_count
  min_count             = var.enable_autoscaling ? var.min_node_count : null
  max_count             = var.enable_autoscaling ? var.max_node_count : null
  
  # Ephemeral OS disk for better performance and cost savings
  os_disk_type = "Ephemeral"
  
  mode = "User"

  node_labels = {
    "workload" = "application"
  }

  node_taints = []

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}

# Role assignment for ACR pull
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}

# Role assignment for network contributor (for load balancer)
resource "azurerm_role_assignment" "network_contributor" {
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name             = "Network Contributor"
  scope                            = var.vnet_subnet_id
  skip_service_principal_aad_check = true
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = replace("acr${var.resource_suffix}", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Enable anonymous pull (for public images if needed)
  anonymous_pull_enabled = false

  # Public network access
  public_network_access_enabled = true

  # Network rule set (Premium SKU only)
  dynamic "network_rule_set" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      default_action = "Allow"
    }
  }

  # Enable zone redundancy for production (Premium SKU only)
  zone_redundancy_enabled = var.sku == "Premium" && var.environment == "production" ? true : false

  tags = var.tags
}

# Scope map for fine-grained access control (Premium SKU only)
resource "azurerm_container_registry_scope_map" "pull" {
  count                   = var.sku == "Premium" ? 1 : 0
  name                    = "pull-scope"
  container_registry_name = azurerm_container_registry.main.name
  resource_group_name     = var.resource_group_name

  actions = [
    "repositories/*/content/read",
    "repositories/*/metadata/read"
  ]
}

# Enable vulnerability scanning (Premium SKU only)
resource "azurerm_container_registry_task" "vulnerability_scan" {
  count                 = var.sku == "Premium" && var.environment == "production" ? 1 : 0
  name                  = "vulnerability-scan"
  container_registry_id = azurerm_container_registry.main.id
  enabled               = true

  platform {
    os = "Linux"
  }

  docker_step {
    dockerfile_path      = "Dockerfile"
    context_path         = "https://github.com/Azure-Samples/acr-tasks.git"
    context_access_token = "placeholder" # Replace with actual token or remove task resource
    image_names          = ["vulnerability-scan:{{.Run.ID}}"]
  }

  tags = var.tags
}

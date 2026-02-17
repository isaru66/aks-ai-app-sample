# Azure AI Services (multi-service account)
resource "azurerm_cognitive_account" "ai_services" {
  name                  = "ai-${var.resource_suffix}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "AIServices"
  sku_name              = var.ai_services_sku_name
  custom_subdomain_name = "ai-${var.resource_suffix}"

  # Network settings
  public_network_access_enabled = !var.enable_private_endpoints

  network_acls {
    default_action = var.enable_private_endpoints ? "Deny" : "Allow"
    ip_rules       = []
  }

  # Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Azure AI Search
resource "azurerm_search_service" "main" {
  count               = var.enable_azure_search_service ? 1 : 0
  name                = "srch-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.search_sku
  replica_count       = var.search_replica_count
  partition_count     = var.search_partition_count

  # Semantic search (Standard SKU and above)
  semantic_search_sku = var.search_sku == "standard" || var.search_sku == "standard2" || var.search_sku == "standard3" ? "standard" : null

  # Public network access
  public_network_access_enabled = !var.enable_private_endpoints

  # Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Azure Content Safety (optional)
resource "azurerm_cognitive_account" "content_safety" {
  count                 = var.enable_content_safety ? 1 : 0
  name                  = "cs-${var.resource_suffix}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "ContentSafety"
  sku_name              = "S0"
  custom_subdomain_name = "cs-${var.resource_suffix}"

  public_network_access_enabled = !var.enable_private_endpoints

  network_acls {
    default_action = var.enable_private_endpoints ? "Deny" : "Allow"
    ip_rules       = []
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Private endpoint for AI Services (if enabled)
resource "azurerm_private_endpoint" "ai_services" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-ai-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-ai-${var.resource_suffix}"
    private_connection_resource_id = azurerm_cognitive_account.ai_services.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  tags = var.tags
}

# Private endpoint for Search (if enabled)
resource "azurerm_private_endpoint" "search" {
  count               = var.enable_private_endpoints && var.enable_azure_search_service ? 1 : 0
  name                = "pe-srch-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-srch-${var.resource_suffix}"
    private_connection_resource_id = azurerm_search_service.main[0].id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  tags = var.tags
}

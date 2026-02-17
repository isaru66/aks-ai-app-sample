# Azure AI Foundry Hub
resource "azurerm_ai_foundry" "hub" {
  name                = "aihub-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  storage_account_id  = var.storage_account_id
  key_vault_id        = var.key_vault_id

  # Optional dependencies
  application_insights_id = var.application_insights_id

  # Identity for managed access
  identity {
    type = "SystemAssigned"
  }

  # Public network access (Enabled or Disabled)
  public_network_access = "Enabled"

  tags = var.tags
}

# Azure AI Foundry Project
resource "azurerm_ai_foundry_project" "project" {
  name               = "ai-proj-${var.resource_suffix}"
  location           = var.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id

  # Identity
  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    var.tags,
    {
      "ParentHub" = azurerm_ai_foundry.hub.name
    }
  )

  depends_on = [azurerm_ai_foundry.hub]
}

# Role assignment for AI Services access
resource "azurerm_role_assignment" "foundry_ai_services" {
  scope                = var.ai_services_id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

# Role assignment for Search access
resource "azurerm_role_assignment" "foundry_search" {
  count                = var.enable_azure_search_service ? 1 : 0
  scope                = var.search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

# Role assignment for Storage access
# resource "azurerm_role_assignment" "foundry_storage" {
#   scope                = var.storage_account_id
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
# }

# Role assignment for Key Vault access
resource "azurerm_role_assignment" "foundry_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

# GPT-5.2 Model Deployment
resource "azurerm_cognitive_deployment" "gpt52" {
  count                = var.deploy_gpt_model ? 1 : 0
  name                 = "gpt-5.2"
  cognitive_account_id = var.ai_services_id

  model {
    format  = "OpenAI"
    name    = "gpt-5.2"
    version = "2025-12-11"
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.gpt_model_capacity
  }

  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  rai_policy_name        = "Microsoft.DefaultV2"

  depends_on = [
    azurerm_role_assignment.foundry_ai_services
  ]
}

# Text Embedding Model Deployment (for RAG)
resource "azurerm_cognitive_deployment" "embedding" {
  count                = var.deploy_embedding_model ? 1 : 0
  name                 = "text-embedding-ada-002"
  cognitive_account_id = var.ai_services_id

  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  sku {
    name     = "Standard"
    capacity = var.embedding_model_capacity
  }

  depends_on = [
    azurerm_role_assignment.foundry_ai_services,
    azurerm_cognitive_deployment.gpt52
  ]
}

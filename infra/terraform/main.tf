locals {
  # Resource naming convention: {resource-type}-{resource_suffix}
  # Example: aks-dev-001, vnet-prod-eastus, cosmos-uat-001

  # Get current workspace
  workspace = terraform.workspace

  # Merged tags
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Workspace   = local.workspace
    }
  )
}

# Data sources
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# Use existing Resource Group
data "azurerm_resource_group" "main" {
  name = "rg-isaru66-aks-terraform-aiapp"
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  environment                     = var.environment
  resource_suffix                 = var.resource_suffix
  vnet_address_space              = var.vnet_address_space
  aks_subnet_prefix               = var.aks_subnet_prefix
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
  tags                            = local.common_tags
}

# Monitoring Module
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  resource_group_name         = data.azurerm_resource_group.main.name
  location                    = data.azurerm_resource_group.main.location
  environment                 = var.environment
  resource_suffix             = var.resource_suffix
  retention_days              = var.log_analytics_retention_days
  enable_application_insights = var.enable_application_insights
  tags                        = local.common_tags
}

# Key Vault Module
module "keyvault" {
  count  = var.enable_keyvault ? 1 : 0
  source = "./modules/keyvault"

  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  environment             = var.environment
  resource_suffix         = var.resource_suffix
  tenant_id               = var.tenant_id
  enable_private_endpoint = var.enable_private_endpoints
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}

# ACR Module
module "acr" {
  count  = var.enable_acr ? 1 : 0
  source = "./modules/acr"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  resource_suffix     = var.resource_suffix
  tags                = local.common_tags
}

# AKS Module
module "aks" {
  count  = var.enable_aks ? 1 : 0
  source = "./modules/aks"

  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  environment                = var.environment
  resource_suffix            = var.resource_suffix
  kubernetes_version         = var.kubernetes_version
  node_count                 = var.aks_node_count
  node_size                  = var.aks_node_size
  enable_autoscaling         = var.enable_autoscaling
  min_node_count             = var.min_node_count
  max_node_count             = var.max_node_count
  vnet_subnet_id             = module.networking.aks_subnet_id
  log_analytics_workspace_id = var.enable_monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  enable_private_cluster     = var.enable_private_cluster
  acr_id                     = var.enable_acr ? module.acr[0].acr_id : null
  tags                       = local.common_tags

  depends_on = [
    module.networking,
    module.monitoring,
    module.acr
  ]
}

# Storage Module
module "storage" {
  count  = var.enable_storage ? 1 : 0
  source = "./modules/storage"

  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  environment             = var.environment
  resource_suffix         = var.resource_suffix
  account_tier            = var.storage_account_tier
  replication_type        = var.storage_replication_type
  enable_private_endpoint = var.enable_private_endpoints
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}

# Cosmos DB Module
module "cosmosdb" {
  count  = var.enable_cosmosdb ? 1 : 0
  source = "./modules/cosmosdb"

  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  environment             = var.environment
  resource_suffix         = var.resource_suffix
  offer_type              = var.cosmosdb_offer_type
  consistency_level       = var.cosmosdb_consistency_level
  enable_free_tier        = var.enable_cosmosdb_free_tier
  enable_private_endpoint = var.enable_private_endpoints
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}

# AI Services Module (Azure AI Search + Content Safety)
module "ai_services" {
  count  = var.enable_ai_services ? 1 : 0
  source = "./modules/ai-services"

  resource_group_name         = data.azurerm_resource_group.main.name
  location                    = var.ai_location
  environment                 = var.environment
  resource_suffix             = var.resource_suffix
  ai_services_sku_name        = var.ai_services_sku_name
  enable_azure_search_service = var.enable_azure_search_service
  search_sku                  = var.search_sku
  search_replica_count        = var.search_replica_count
  search_partition_count      = var.search_partition_count
  enable_content_safety       = var.enable_content_safety
  enable_private_endpoints    = var.enable_private_endpoints
  subnet_id                   = module.networking.private_endpoints_subnet_id
  tags                        = local.common_tags
}

# AI Foundry Module (Hub + Project)
module "ai_foundry" {
  count  = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? 1 : 0
  source = "./modules/ai-foundry"

  resource_group_name         = data.azurerm_resource_group.main.name
  location                    = var.ai_location
  environment                 = var.environment
  resource_suffix             = var.resource_suffix
  ai_services_id              = module.ai_services[0].ai_services_id
  search_id                   = var.enable_azure_search_service ? module.ai_services[0].search_id : null
  enable_azure_search_service = var.enable_azure_search_service
  storage_account_id          = module.storage[0].storage_account_id
  key_vault_id                = module.keyvault[0].key_vault_id
  application_insights_id     = var.enable_monitoring ? module.monitoring[0].application_insights_id : null
  
  # Model deployment settings
  deploy_gpt_model          = var.deploy_gpt_model
  gpt_model_capacity        = var.gpt_model_capacity
  deploy_embedding_model    = var.deploy_embedding_model
  embedding_model_capacity  = var.embedding_model_capacity
  
  tags = local.common_tags

  depends_on = [
    module.ai_services,
    module.storage,
    module.keyvault
  ]
}

# Service Principal Module
module "service_principal" {
  count  = var.enable_service_principal && var.enable_ai_services ? 1 : 0
  source = "./modules/service-principal"

  environment        = var.environment
  resource_suffix    = var.resource_suffix
  ai_services_id     = module.ai_services[0].ai_services_id
  storage_account_id = var.enable_storage ? module.storage[0].storage_account_id : null
  key_vault_id       = var.enable_keyvault ? module.keyvault[0].key_vault_id : null
  
  assign_storage_role  = var.enable_storage
  assign_keyvault_role = var.enable_keyvault
  
  tags = local.common_tags

  depends_on = [
    module.ai_services,
    module.storage,
    module.keyvault
  ]
}

# Debug output for AI Foundry module condition
output "debug_ai_foundry_enabled" {
  description = "Debug: AI Foundry module creation condition"
  value = {
    enable_ai_foundry  = var.enable_ai_foundry
    enable_ai_services = var.enable_ai_services
    enable_storage     = var.enable_storage
    enable_keyvault    = var.enable_keyvault
    condition_result   = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault
    module_count       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? 1 : 0
  }
}

# Store secrets in Key Vault
# resource "azurerm_key_vault_secret" "ai_services_key" {
#   count        = var.enable_keyvault && var.enable_ai_services ? 1 : 0
#   name         = "azure-ai-services-api-key"
#   value        = module.ai_services[0].ai_services_primary_key
#   key_vault_id = module.keyvault[0].key_vault_id

#   depends_on = [
#     module.keyvault,
#     module.ai_services
#   ]
# }

resource "azurerm_key_vault_secret" "ai_services_endpoint" {
  count        = var.enable_keyvault && var.enable_ai_services ? 1 : 0
  name         = "azure-ai-services-endpoint"
  value        = module.ai_services[0].ai_services_endpoint
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.ai_services
  ]
}

resource "azurerm_key_vault_secret" "ai_foundry_endpoint" {
  count        = var.enable_keyvault && var.enable_ai_foundry && var.enable_ai_services && var.enable_storage ? 1 : 0
  name         = "azure-ai-foundry-endpoint"
  value        = module.ai_foundry[0].project_endpoint
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.ai_foundry
  ]
}

resource "azurerm_key_vault_secret" "search_key" {
  count        = var.enable_keyvault && var.enable_ai_services && var.enable_azure_search_service ? 1 : 0
  name         = "azure-search-api-key"
  value        = module.ai_services[0].search_primary_key
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.ai_services
  ]
}

resource "azurerm_key_vault_secret" "cosmosdb_key" {
  count        = var.enable_keyvault && var.enable_cosmosdb ? 1 : 0
  name         = "azure-cosmosdb-key"
  value        = module.cosmosdb[0].primary_key
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.cosmosdb
  ]
}

# Service Principal Client Secret in Key Vault
resource "azurerm_key_vault_secret" "sp_client_id" {
  count        = var.enable_keyvault && var.enable_service_principal && var.enable_ai_services ? 1 : 0
  name         = "service-principal-client-id"
  value        = module.service_principal[0].client_id
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.service_principal
  ]
}

resource "azurerm_key_vault_secret" "sp_client_secret" {
  count        = var.enable_keyvault && var.enable_service_principal && var.enable_ai_services ? 1 : 0
  name         = "service-principal-client-secret"
  value        = module.service_principal[0].client_secret
  key_vault_id = module.keyvault[0].key_vault_id

  depends_on = [
    module.keyvault,
    module.service_principal
  ]
}

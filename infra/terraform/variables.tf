# General variables
variable "environment" {
  description = "Environment name (dev, sit, uat, production)"
  type        = string
  validation {
    condition     = contains(["dev", "sit", "uat", "production"], var.environment)
    error_message = "Environment must be one of: dev, sit, uat, production"
  }
}

variable "location" {
  description = "Azure region for main resources"
  type        = string
  default     = "southeastasia"
}

variable "ai_location" {
  description = "Azure region for AI services (Azure AI Foundry)"
  type        = string
  default     = "swedencentral"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "resource_suffix" {
  description = "Resource suffix for naming (e.g., 'dev-001', 'prod-eastus')"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "AKS-AI-App"
  }
}

# AKS variables
variable "aks_node_count" {
  description = "Initial number of nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_node_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4ads_v5"
}

variable "enable_autoscaling" {
  description = "Enable AKS autoscaling"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "enable_private_cluster" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = false
}

# Azure AI Services variables
variable "ai_services_sku_name" {
  description = "Azure AI Services SKU"
  type        = string
  default     = "S0"
}

# Azure AI Search variables
variable "search_sku" {
  description = "Azure AI Search SKU"
  type        = string
  default     = "standard"
}

variable "search_replica_count" {
  description = "Number of search replicas"
  type        = number
  default     = 1
}

variable "search_partition_count" {
  description = "Number of search partitions"
  type        = number
  default     = 1
}

# Cosmos DB variables
variable "cosmosdb_offer_type" {
  description = "Cosmos DB offer type"
  type        = string
  default     = "Standard"
}

variable "cosmosdb_consistency_level" {
  description = "Cosmos DB consistency level"
  type        = string
  default     = "Session"
}

variable "enable_cosmosdb_free_tier" {
  description = "Enable Cosmos DB free tier (only one per subscription)"
  type        = bool
  default     = false
}

# Storage variables
variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "LRS"
}

# Networking variables
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "AKS subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoints_subnet_prefix" {
  description = "Private endpoints subnet address prefix"
  type        = string
  default     = "10.0.2.0/24"
}

# Monitoring variables
variable "log_analytics_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "enable_application_insights" {
  description = "Enable Application Insights"
  type        = bool
  default     = true
}

# Feature flags
variable "enable_ai_foundry" {
  description = "Enable Azure AI Foundry"
  type        = bool
  default     = true
}

variable "enable_content_safety" {
  description = "Enable Azure Content Safety"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for services"
  type        = bool
  default     = false
}

variable "enable_azure_search_service" {
  description = "Enable Azure AI Search service"
  type        = bool
  default     = false
}

# AI Model deployment flags
variable "deploy_gpt_model" {
  description = "Deploy GPT-5.2 model in AI Foundry"
  type        = bool
  default     = true
}

variable "gpt_model_capacity" {
  description = "GPT-5.2 model capacity (TPM in thousands)"
  type        = number
  default     = 500
}

variable "deploy_embedding_model" {
  description = "Deploy text-embedding-ada-002 model in AI Foundry"
  type        = bool
  default     = true
}

variable "embedding_model_capacity" {
  description = "Embedding model capacity (TPM in thousands)"
  type        = number
  default     = 100
}

# Module enable/disable flags
variable "enable_monitoring" {
  description = "Enable monitoring module (Log Analytics, Application Insights)"
  type        = bool
  default     = true
}

variable "enable_keyvault" {
  description = "Enable Key Vault module"
  type        = bool
  default     = true
}

variable "enable_acr" {
  description = "Enable Azure Container Registry"
  type        = bool
  default     = true
}

variable "enable_aks" {
  description = "Enable Azure Kubernetes Service"
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable Azure Storage Account"
  type        = bool
  default     = true
}

variable "enable_cosmosdb" {
  description = "Enable Azure Cosmos DB"
  type        = bool
  default     = false
}

variable "enable_ai_services" {
  description = "Enable AI Services module (AI Services, Search, Content Safety)"
  type        = bool
  default     = true
}

variable "enable_service_principal" {
  description = "Enable service principal creation for application authentication"
  type        = bool
  default     = true
}

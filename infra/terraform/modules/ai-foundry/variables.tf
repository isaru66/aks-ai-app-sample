variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, sit, uat, production)"
  type        = string
}

variable "resource_suffix" {
  description = "Suffix for resource naming"
  type        = string
}

variable "application_insights_id" {
  description = "Application Insights resource ID"
  type        = string
}

variable "enable_azure_search_service" {
  description = "Enable Azure AI Search service"
  type        = bool
  default     = false
}

variable "ai_services_id" {
  description = "Azure AI Services account ID"
  type        = string
}

variable "search_id" {
  description = "Azure AI Search ID"
  type        = string
  default     = null
}

variable "storage_account_id" {
  description = "Storage account ID"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Model deployment variables
variable "deploy_gpt_model" {
  description = "Deploy GPT-5.2 model"
  type        = bool
  default     = true
}

variable "gpt_model_capacity" {
  description = "GPT-5.2 model capacity (TPM in thousands)"
  type        = number
  default     = 500
}

variable "deploy_embedding_model" {
  description = "Deploy text-embedding-ada-002 model"
  type        = bool
  default     = true
}

variable "embedding_model_capacity" {
  description = "Embedding model capacity (TPM in thousands)"
  type        = number
  default     = 100
}

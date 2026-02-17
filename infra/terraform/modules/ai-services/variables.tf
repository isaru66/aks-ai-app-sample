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

variable "enable_azure_search_service" {
  description = "Enable Azure AI Search service"
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

# Feature flags
variable "enable_content_safety" {
  description = "Enable Azure Content Safety"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for private endpoints"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

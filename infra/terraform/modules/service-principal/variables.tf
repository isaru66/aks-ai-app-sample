variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "resource_suffix" {
  description = "Resource suffix for naming"
  type        = string
}

variable "ai_services_id" {
  description = "Azure AI Services resource ID"
  type        = string
}

variable "storage_account_id" {
  description = "Storage Account resource ID (optional)"
  type        = string
  default     = null
}

variable "key_vault_id" {
  description = "Key Vault resource ID (optional)"
  type        = string
  default     = null
}

variable "assign_storage_role" {
  description = "Assign Storage Blob Data Contributor role"
  type        = bool
  default     = true
}

variable "assign_keyvault_role" {
  description = "Assign Key Vault Secrets User role"
  type        = bool
  default     = true
}

variable "client_secret_expiration_years" {
  description = "Client secret expiration in years"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

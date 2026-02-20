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
  description = "Suffix for resource naming (e.g., 'isaru66-aiapp-asse-001')"
  type        = string
}

# --- Credentials ---

variable "administrator_login" {
  description = "PostgreSQL administrator login name"
  type        = string
  default     = "psqladmin"
}

variable "administrator_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

# --- Compute & Storage ---

variable "sku_name" {
  description = "PostgreSQL Flexible Server SKU (e.g., B_Standard_B2s, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B2s"
}

variable "pg_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "storage_mb" {
  description = "Max storage in megabytes"
  type        = number
  default     = 32768 # 32 GB
}

variable "storage_tier" {
  description = "Storage performance tier (P4, P6, P10, P15, P20, P30, P40, P50)"
  type        = string
  default     = "P4"
}

variable "zone" {
  description = "Availability zone for the server (1, 2, or 3)"
  type        = string
  default     = "1"
}

variable "auto_grow_enabled" {
  description = "Enable storage auto-grow"
  type        = bool
  default     = false
}

# --- Backup ---

variable "backup_retention_days" {
  description = "Backup retention period in days (7–35)"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

# --- Network ---

variable "public_network_access_enabled" {
  description = "Allow public network access to the server"
  type        = bool
  default     = true
}

variable "allow_azure_services" {
  description = "Add a firewall rule that allows all Azure-internal IPs (0.0.0.0)"
  type        = bool
  default     = true
}

variable "enable_vnet_integration" {
  description = "Integrate the server into a VNet via delegated subnet"
  type        = bool
  default     = false
}

variable "delegated_subnet_id" {
  description = "ID of the delegated subnet for VNet integration"
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for VNet integration"
  type        = string
  default     = null
}

# --- Authentication ---

variable "active_directory_auth_enabled" {
  description = "Enable Azure Active Directory authentication"
  type        = bool
  default     = true
}

variable "password_auth_enabled" {
  description = "Enable password authentication"
  type        = bool
  default     = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID (required when active_directory_auth_enabled = true)"
  type        = string
  default     = null
}

# --- Database ---

variable "database_name" {
  description = "Name of the default application database to create"
  type        = string
  default     = "chatdb"
}

# --- Tags ---

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  sku_name   = var.sku_name
  version    = var.pg_version
  storage_mb = var.storage_mb
  storage_tier = var.storage_tier
  zone         = var.zone

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  auto_grow_enabled            = var.auto_grow_enabled

  public_network_access_enabled = var.public_network_access_enabled

  # VNet integration (optional — required when enable_vnet_integration = true)
  delegated_subnet_id = var.enable_vnet_integration ? var.delegated_subnet_id : null
  private_dns_zone_id = var.enable_vnet_integration ? var.private_dns_zone_id : null

  authentication {
    active_directory_auth_enabled = var.active_directory_auth_enabled
    password_auth_enabled         = var.password_auth_enabled
    tenant_id                     = var.active_directory_auth_enabled ? var.tenant_id : null
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore zone changes to prevent recreation on plan
      zone,
    ]
  }
}

# Default application database
resource "azurerm_postgresql_flexible_server_database" "app_db" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule — allow Azure services (only when public access enabled)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count      = var.public_network_access_enabled && var.allow_azure_services ? 1 : 0
  name       = "AllowAllAzureServicesAndResourcesWithinAzureIps"
  server_id  = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

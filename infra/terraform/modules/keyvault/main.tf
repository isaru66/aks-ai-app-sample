data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                          = "kv${replace(var.resource_suffix, "-", "")}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 90
  purge_protection_enabled      = var.environment == "production" ? true : false
  rbac_authorization_enabled    = true
  public_network_access_enabled = !var.enable_private_endpoint

  # Network ACLs
  network_acls {
    default_action = var.enable_private_endpoint ? "Deny" : "Allow"
    bypass         = "AzureServices"
    ip_rules       = []
  }

  tags = var.tags
}

# Role assignment for current user/service principal (Key Vault Administrator)
resource "azurerm_role_assignment" "current_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Private endpoint (if enabled)
resource "azurerm_private_endpoint" "keyvault" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-kv-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv-${var.resource_suffix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = var.tags
}

# Private DNS zone for Key Vault (if private endpoint enabled)
resource "azurerm_private_dns_zone" "keyvault" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link private DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "pdnsl-kv-${var.resource_suffix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = "/subscriptions/${split("/", var.subnet_id)[2]}/resourceGroups/${split("/", var.subnet_id)[4]}/providers/Microsoft.Network/virtualNetworks/${split("/", var.subnet_id)[8]}"
  tags                  = var.tags
}

# Data source for subnet (to get VNet ID)
data "azurerm_subnet" "main" {
  count                = var.enable_private_endpoint ? 1 : 0
  name                 = split("/", var.subnet_id)[10]
  virtual_network_name = split("/", var.subnet_id)[8]
  resource_group_name  = var.resource_group_name
}

# Private DNS A record
resource "azurerm_private_dns_a_record" "keyvault" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = azurerm_key_vault.main.name
  zone_name           = azurerm_private_dns_zone.keyvault[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.keyvault[0].private_service_connection[0].private_ip_address]
  tags                = var.tags
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "private_endpoint_ip" {
  description = "Private endpoint IP address"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.keyvault[0].private_service_connection[0].private_ip_address : null
}

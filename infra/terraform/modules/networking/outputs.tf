output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks.id
}

output "aks_subnet_name" {
  description = "AKS subnet name"
  value       = azurerm_subnet.aks.name
}

output "private_endpoints_subnet_id" {
  description = "Private endpoints subnet ID"
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoints_subnet_name" {
  description = "Private endpoints subnet name"
  value       = azurerm_subnet.private_endpoints.name
}

output "aks_nsg_id" {
  description = "AKS Network Security Group ID"
  value       = azurerm_network_security_group.aks.id
}

output "private_endpoints_nsg_id" {
  description = "Private endpoints Network Security Group ID"
  value       = azurerm_network_security_group.private_endpoints.id
}

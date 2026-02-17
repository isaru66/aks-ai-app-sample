output "ai_services_id" {
  description = "Azure AI Services account ID"
  value       = azurerm_cognitive_account.ai_services.id
}

output "ai_services_name" {
  description = "Azure AI Services account name"
  value       = azurerm_cognitive_account.ai_services.name
}

output "ai_services_endpoint" {
  description = "Azure AI Services endpoint"
  value       = azurerm_cognitive_account.ai_services.endpoint
}

output "ai_services_primary_key" {
  description = "Azure AI Services primary key"
  value       = azurerm_cognitive_account.ai_services.primary_access_key
  sensitive   = true
}

output "ai_services_secondary_key" {
  description = "Azure AI Services secondary key"
  value       = azurerm_cognitive_account.ai_services.secondary_access_key
  sensitive   = true
}

output "search_id" {
  description = "Azure AI Search ID"
  value       = var.enable_azure_search_service ? azurerm_search_service.main[0].id : null
}

output "search_name" {
  description = "Azure AI Search name"
  value       = var.enable_azure_search_service ? azurerm_search_service.main[0].name : null
}

output "search_endpoint" {
  description = "Azure AI Search endpoint"
  value       = var.enable_azure_search_service ? "https://${azurerm_search_service.main[0].name}.search.windows.net" : null
}

output "search_primary_key" {
  description = "Azure AI Search primary key"
  value       = var.enable_azure_search_service ? azurerm_search_service.main[0].primary_key : null
  sensitive   = true
}

output "search_secondary_key" {
  description = "Azure AI Search secondary key"
  value       = var.enable_azure_search_service ? azurerm_search_service.main[0].secondary_key : null
  sensitive   = true
}

output "content_safety_id" {
  description = "Content Safety account ID"
  value       = var.enable_content_safety ? azurerm_cognitive_account.content_safety[0].id : null
}

output "content_safety_endpoint" {
  description = "Content Safety endpoint"
  value       = var.enable_content_safety ? azurerm_cognitive_account.content_safety[0].endpoint : null
}

output "content_safety_key" {
  description = "Content Safety primary key"
  value       = var.enable_content_safety ? azurerm_cognitive_account.content_safety[0].primary_access_key : null
  sensitive   = true
}

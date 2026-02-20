# Resource Group Outputs
output "resource_group_name" {
  description = "Resource group name"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = data.azurerm_resource_group.main.location
}

# AKS Outputs
output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = var.enable_aks ? module.aks[0].cluster_name : null
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = var.enable_aks ? module.aks[0].cluster_id : null
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = var.enable_aks ? module.aks[0].cluster_fqdn : null
}

output "aks_kube_config_command" {
  description = "Command to configure kubectl"
  value       = var.enable_aks ? "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${module.aks[0].cluster_name}" : null
}

# ACR Outputs
output "acr_name" {
  description = "Azure Container Registry name"
  value       = var.enable_acr ? module.acr[0].acr_name : null
}

output "acr_login_server" {
  description = "ACR login server"
  value       = var.enable_acr ? module.acr[0].acr_login_server : null
}

# Azure AI Services Outputs
output "ai_services_endpoint" {
  description = "Azure AI Services endpoint"
  value       = var.enable_ai_services ? module.ai_services[0].ai_services_endpoint : null
}

output "ai_services_name" {
  description = "Azure AI Services name"
  value       = var.enable_ai_services ? module.ai_services[0].ai_services_name : null
}

# Azure AI Search Outputs
output "search_endpoint" {
  description = "Azure AI Search endpoint"
  value       = var.enable_ai_services && var.enable_azure_search_service ? module.ai_services[0].search_endpoint : null
}

output "search_name" {
  description = "Azure AI Search service name"
  value       = var.enable_ai_services && var.enable_azure_search_service ? module.ai_services[0].search_name : null
}

# Storage Outputs
output "storage_account_name" {
  description = "Storage account name"
  value       = var.enable_storage ? module.storage[0].storage_account_name : null
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage account primary blob endpoint"
  value       = var.enable_storage ? module.storage[0].primary_blob_endpoint : null
}

# Key Vault Outputs
output "key_vault_name" {
  description = "Key Vault name"
  value       = var.enable_keyvault ? module.keyvault[0].key_vault_name : null
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = var.enable_keyvault ? module.keyvault[0].key_vault_uri : null
}

# AI Foundry Outputs (conditional)
output "ai_foundry_hub_id" {
  description = "Azure AI Foundry Hub ID"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].hub_id : null
}

output "ai_foundry_hub_name" {
  description = "Azure AI Foundry Hub name"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].hub_name : null
}

output "ai_foundry_project_id" {
  description = "Azure AI Foundry Project ID"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].project_id : null
}

output "ai_foundry_project_name" {
  description = "Azure AI Foundry Project name"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].project_name : null
}

output "ai_foundry_project_endpoint" {
  description = "Azure AI Foundry Project endpoint"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].project_endpoint : null
}

output "ai_foundry_gpt52_deployment" {
  description = "GPT-5.2 deployment name"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].gpt52_deployment_name : null
}

output "ai_foundry_embedding_deployment" {
  description = "Text embedding deployment name"
  value       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? module.ai_foundry[0].embedding_deployment_name : null
}

# Monitoring Outputs
output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = var.enable_monitoring && var.enable_application_insights ? module.monitoring[0].application_insights_connection_string : null
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = var.enable_monitoring && var.enable_application_insights ? module.monitoring[0].application_insights_instrumentation_key : null
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = var.enable_monitoring ? module.monitoring[0].log_analytics_workspace_id : null
}

# Networking Outputs
output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = module.networking.aks_subnet_id
}

# Environment Information
output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

# PostgreSQL Outputs
output "postgresql_server_name" {
  description = "PostgreSQL Flexible Server name"
  value       = var.enable_postgresql ? module.postgresql[0].server_name : null
}

output "postgresql_fqdn" {
  description = "PostgreSQL server fully qualified domain name"
  value       = var.enable_postgresql ? module.postgresql[0].fqdn : null
}

output "postgresql_database_name" {
  description = "PostgreSQL default database name"
  value       = var.enable_postgresql ? module.postgresql[0].database_name : null
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string (passwordless placeholder)"
  value       = var.enable_postgresql ? module.postgresql[0].connection_string : null
}

# Service Principal Outputs
output "service_principal_client_id" {
  description = "Service Principal Client ID (Application ID)"
  value       = var.enable_service_principal && var.enable_ai_services ? module.service_principal[0].client_id : null
}

output "service_principal_client_secret" {
  description = "Service Principal Client Secret"
  value       = var.enable_service_principal && var.enable_ai_services ? module.service_principal[0].client_secret : null
  sensitive   = true
}

output "service_principal_tenant_id" {
  description = "Azure AD Tenant ID"
  value       = var.enable_service_principal && var.enable_ai_services ? module.service_principal[0].tenant_id : null
}

output "service_principal_object_id" {
  description = "Service Principal Object ID"
  value       = var.enable_service_principal && var.enable_ai_services ? module.service_principal[0].object_id : null
}

# Quick Start Commands
output "quick_start_commands" {
  description = "Quick start commands for deployment"
  value = {
    configure_kubectl = var.enable_aks ? "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${module.aks[0].cluster_name}" : "AKS not enabled"
    acr_login         = var.enable_acr ? "az acr login --name ${module.acr[0].acr_name}" : "ACR not enabled"
    view_key_vault    = var.enable_keyvault ? "az keyvault show --name ${module.keyvault[0].key_vault_name}" : "Key Vault not enabled"
  }
}

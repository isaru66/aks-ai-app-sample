output "hub_id" {
  description = "AI Foundry Hub ID"
  value       = azurerm_ai_foundry.hub.id
}

output "hub_name" {
  description = "AI Foundry Hub name"
  value       = azurerm_ai_foundry.hub.name
}

output "project_id" {
  description = "AI Foundry Project ID"
  value       = azurerm_ai_foundry_project.project.id
}

output "project_name" {
  description = "AI Foundry Project name"
  value       = azurerm_ai_foundry_project.project.name
}

output "project_endpoint" {
  description = "AI Foundry Project endpoint"
  value       = "https://${azurerm_ai_foundry_project.project.name}.api.azureml.ms"
}

output "hub_principal_id" {
  description = "AI Foundry Hub managed identity principal ID"
  value       = azurerm_ai_foundry.hub.identity[0].principal_id
}

output "gpt52_deployment_name" {
  description = "GPT-5.2 deployment name"
  value       = var.deploy_gpt_model ? azurerm_cognitive_deployment.gpt52[0].name : null
}

output "gpt52_model_version" {
  description = "GPT-5.2 model version"
  value       = var.deploy_gpt_model ? azurerm_cognitive_deployment.gpt52[0].model[0].version : null
}

output "embedding_deployment_name" {
  description = "Text embedding deployment name"
  value       = var.deploy_embedding_model ? azurerm_cognitive_deployment.embedding[0].name : null
}

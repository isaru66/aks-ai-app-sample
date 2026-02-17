output "storage_account_id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_queue_endpoint" {
  description = "Primary queue endpoint"
  value       = azurerm_storage_account.main.primary_queue_endpoint
}

output "documents_container_name" {
  description = "Documents container name"
  value       = azurerm_storage_container.documents.name
}

output "backups_container_name" {
  description = "Backups container name"
  value       = azurerm_storage_container.backups.name
}

output "processing_queue_name" {
  description = "Processing queue name"
  value       = azurerm_storage_queue.processing.name
}

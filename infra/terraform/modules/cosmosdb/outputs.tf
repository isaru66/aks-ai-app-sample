output "account_id" {
  description = "Cosmos DB account ID"
  value       = azurerm_cosmosdb_account.main.id
}

output "account_name" {
  description = "Cosmos DB account name"
  value       = azurerm_cosmosdb_account.main.name
}

output "endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "primary_key" {
  description = "Cosmos DB primary key"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "secondary_key" {
  description = "Cosmos DB secondary key"
  value       = azurerm_cosmosdb_account.main.secondary_key
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = azurerm_cosmosdb_sql_database.main.name
}

output "conversations_container_name" {
  description = "Conversations container name"
  value       = azurerm_cosmosdb_sql_container.conversations.name
}

output "messages_container_name" {
  description = "Messages container name"
  value       = azurerm_cosmosdb_sql_container.messages.name
}

output "users_container_name" {
  description = "Users container name"
  value       = azurerm_cosmosdb_sql_container.users.name
}

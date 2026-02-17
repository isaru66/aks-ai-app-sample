# Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.offer_type
  kind                = "GlobalDocumentDB"

  # Free tier (only one per subscription)
  free_tier_enabled = var.enable_free_tier

  # Automatic failover
  automatic_failover_enabled = var.environment == "production" ? true : false

  # Multiple write locations (production only)
  multiple_write_locations_enabled = var.environment == "production" ? true : false

  # Consistency policy
  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.consistency_level == "BoundedStaleness" ? 10 : null
    max_staleness_prefix    = var.consistency_level == "BoundedStaleness" ? 200 : null
  }

  # Geo-replication (production: multi-region, others: single region)
  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.environment == "production" ? true : false
  }

  dynamic "geo_location" {
    for_each = var.environment == "production" ? [1] : []
    content {
      location          = var.location == "eastus" ? "westus" : "eastus"
      failover_priority = 1
      zone_redundant    = true
    }
  }

  # Capabilities
  capabilities {
    name = "EnableServerless" # Serverless mode for cost savings in non-production
  }

  # Backup
  backup {
    type                = var.environment == "production" ? "Continuous" : "Periodic"
    interval_in_minutes = var.environment == "production" ? null : 240
    retention_in_hours  = var.environment == "production" ? null : 8
    storage_redundancy  = var.environment == "production" ? "Geo" : "Local"
  }

  # Network
  public_network_access_enabled     = !var.enable_private_endpoint
  is_virtual_network_filter_enabled = var.enable_private_endpoint

  tags = var.tags
}

# SQL Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "chatdb"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name

  # Throughput (not needed for serverless)
  # throughput = 400
}

# SQL Container for conversations
resource "azurerm_cosmosdb_sql_container" "conversations" {
  name                = "conversations"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/userId"]

  # Indexing policy
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }

  # Unique key
  unique_key {
    paths = ["/sessionId"]
  }

  # TTL (time to live) - auto-delete old conversations
  default_ttl = var.environment == "production" ? -1 : 2592000 # 30 days in non-prod
}

# SQL Container for messages
resource "azurerm_cosmosdb_sql_container" "messages" {
  name                = "messages"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/conversationId"]

  # Indexing policy
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    included_path {
      path = "/timestamp/?"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }

  # TTL - messages expire after 90 days (configurable)
  default_ttl = 7776000 # 90 days
}

# SQL Container for user profiles
resource "azurerm_cosmosdb_sql_container" "users" {
  name                = "users"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/userId"]

  # Indexing policy
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }

  # No TTL for user profiles
  default_ttl = -1
}

# Private endpoint (if enabled)
resource "azurerm_private_endpoint" "cosmos" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-cosmos-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-cosmos-${var.resource_suffix}"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  tags = var.tags
}

# Cosmos DB Module

This module creates an Azure Cosmos DB account with SQL API for chat data storage.

## Resources Created

- Cosmos DB Account (Serverless)
- SQL Database (`chatdb`)
- SQL Containers:
  - `conversations` - Chat sessions
  - `messages` - Chat messages with thinking steps
  - `users` - User profiles
- Private endpoint (optional)

## Usage

```hcl
module "cosmosdb" {
  source = "./modules/cosmosdb"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  environment             = "dev"
  resource_prefix         = "aks-ai-app-dev"
  random_suffix           = random_string.suffix.result
  offer_type              = "Standard"
  consistency_level       = "Session"
  enable_free_tier        = false
  enable_private_endpoint = false
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}
```

## Data Model

### Conversations Container
```json
{
  "id": "uuid",
  "userId": "user123",
  "sessionId": "session-uuid",
  "title": "Chat about AI",
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-02-01T01:00:00Z"
}
```

### Messages Container
```json
{
  "id": "uuid",
  "conversationId": "conversation-uuid",
  "role": "assistant",
  "content": "Response text",
  "thinkingSteps": [
    {
      "stepNumber": 1,
      "reasoning": "First, I need to...",
      "confidence": 0.95
    }
  ],
  "timestamp": "2026-02-01T00:00:00Z"
}
```

## Features

- ✅ **Serverless Mode** - Pay per request (cost-optimized)
- ✅ **Automatic Failover** - Production high availability
- ✅ **Geo-Replication** - Multi-region in production
- ✅ **TTL** - Auto-delete old data
- ✅ **Backup** - Continuous backup in production
- ✅ **Indexing** - Optimized query performance

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| offer_type | Offer type | string | "Standard" | no |
| consistency_level | Consistency level | string | "Session" | no |
| enable_free_tier | Enable free tier | bool | false | no |
| enable_private_endpoint | Enable private endpoint | bool | false | no |
| subnet_id | Subnet ID | string | null | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| endpoint | Cosmos DB endpoint |
| primary_key | Primary key (sensitive) |
| database_name | Database name |
| conversations_container_name | Conversations container |
| messages_container_name | Messages container |

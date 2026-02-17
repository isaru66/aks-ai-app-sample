# AI Services Module

This module creates Azure AI services including **Azure AI Services** (multi-service account), Azure AI Search, and Content Safety.

## Resources Created

- **Azure AI Services** (multi-service account supporting OpenAI, Computer Vision, Speech, etc.)
- **Azure AI Search** with semantic search
- **Azure Content Safety** (optional)
- Private endpoints (optional)

## Usage

```hcl
module "ai_services" {
  source = "./modules/ai-services"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = "swedencentral"  # AI services region
  environment              = "dev"
  resource_suffix          = "dev-001"
  random_suffix            = random_string.suffix.result
  ai_services_sku_name     = "S0"
  search_sku               = "standard"
  search_replica_count     = 1
  search_partition_count   = 1
  enable_content_safety    = true
  enable_private_endpoints = false
  subnet_id                = module.networking.private_endpoints_subnet_id
  tags                     = local.common_tags
}
```

## Azure AI Services

The Azure AI Services multi-service account provides:

✅ **OpenAI Models** - GPT-4, GPT-3.5, embeddings, DALL-E  
✅ **Computer Vision** - Image analysis, OCR  
✅ **Speech Services** - Speech-to-text, text-to-speech  
✅ **Language Services** - Translation, entity recognition  
✅ **Single Endpoint** - Unified access to all services  

Models are deployed via Azure AI Foundry projects, not directly in this module.

## Azure AI Search

Features enabled:
- **Semantic Search** - Better relevance ranking
- **Vector Search** - Embedding-based search for RAG
- **Hybrid Search** - Combine keyword + semantic + vector
- **Configurable Replicas** - High availability

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_suffix | Suffix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| ai_services_sku_name | AI Services SKU | string | "S0" | no |
| search_sku | Search SKU | string | "standard" | no |
| search_replica_count | Replicas | number | 1 | no |
| search_partition_count | Partitions | number | 1 | no |
| enable_content_safety | Enable Content Safety | bool | true | no |
| enable_private_endpoints | Enable private endpoints | bool | false | no |
| subnet_id | Subnet ID | string | null | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| ai_services_endpoint | Azure AI Services endpoint |
| ai_services_primary_key | Primary key (sensitive) |
| search_endpoint | AI Search endpoint |
| search_primary_key | Search key (sensitive) |

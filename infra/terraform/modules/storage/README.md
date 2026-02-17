# Storage Module

This module creates Azure Storage Account with containers, queues, and lifecycle policies.

## Resources Created

- Storage Account (StorageV2 with Data Lake Gen2)
- Blob containers:
  - `documents` - For user documents
  - `backups` - For backups
- Storage queue for async processing
- Private endpoints (optional)
- Lifecycle management policies

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  environment             = "dev"
  resource_prefix         = "aks-ai-app-dev"
  random_suffix           = random_string.suffix.result
  account_tier            = "Standard"
  replication_type        = "LRS"
  enable_private_endpoint = false
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}
```

## Features

- ✅ **Data Lake Gen2** - Hierarchical namespace enabled
- ✅ **Soft Delete** - 7-day retention for blobs and containers
- ✅ **Versioning** - Enabled in production
- ✅ **Lifecycle Policies** - Automatic archival and deletion
- ✅ **Private Endpoints** - Optional network isolation
- ✅ **HTTPS Only** - Secure transfer required
- ✅ **TLS 1.2+** - Minimum TLS version

## Lifecycle Policies

### Backup Retention
- Delete backups older than 90 days

### Document Archival (Production)
- Move to Cool tier after 30 days
- Move to Archive tier after 90 days

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| account_tier | Storage tier | string | "Standard" | no |
| replication_type | Replication type | string | "LRS" | no |
| enable_private_endpoint | Enable private endpoint | bool | false | no |
| subnet_id | Subnet ID | string | null | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| storage_account_id | Storage account ID |
| storage_account_name | Storage account name |
| primary_blob_endpoint | Primary blob endpoint |
| primary_access_key | Primary access key (sensitive) |

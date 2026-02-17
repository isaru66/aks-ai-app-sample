# Azure Container Registry Module

This module creates an Azure Container Registry for storing Docker images.

## Resources Created

- Azure Container Registry
- Scope maps (Premium SKU)
- Vulnerability scanning task (Premium SKU, production only)

## Usage

```hcl
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = "dev"
  resource_prefix     = "aks-ai-app-dev"
  random_suffix       = random_string.suffix.result
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.common_tags
}
```

## SKU Comparison

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| Storage | 10 GB | 100 GB | 500 GB |
| Webhooks | 2 | 10 | 500 |
| Geo-replication | ❌ | ❌ | ✅ |
| Content trust | ❌ | ❌ | ✅ |
| Private link | ❌ | ❌ | ✅ |
| Zone redundancy | ❌ | ❌ | ✅ |
| Vulnerability scanning | ❌ | ❌ | ✅ |

## Security Best Practices

- ✅ **Disable admin user** - Use managed identity or service principal
- ✅ **Enable vulnerability scanning** (Premium SKU)
- ✅ **Use private endpoints** for production (Premium SKU)
- ✅ **Enable content trust** (Premium SKU)
- ✅ **Implement retention policies**

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| sku | ACR SKU | string | "Standard" | no |
| admin_enabled | Enable admin user | bool | false | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| acr_id | ACR ID |
| acr_name | ACR name |
| acr_login_server | ACR login server URL |

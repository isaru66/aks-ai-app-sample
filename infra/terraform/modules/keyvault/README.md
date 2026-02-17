# Key Vault Module

This module creates an Azure Key Vault for secrets management with optional private endpoint support.

## Resources Created

- Azure Key Vault with RBAC authorization
- Private endpoint (optional)
- Private DNS zone (optional)
- Role assignments

## Usage

```hcl
module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  environment             = "dev"
  resource_prefix         = "aks-ai-app-dev"
  tenant_id               = var.tenant_id
  enable_private_endpoint = false
  subnet_id               = module.networking.private_endpoints_subnet_id
  tags                    = local.common_tags
}
```

## Security Features

- ✅ **RBAC Authorization** - Role-based access control (no access policies)
- ✅ **Soft Delete** - 90-day retention for deleted secrets
- ✅ **Purge Protection** - Enabled in production
- ✅ **Private Endpoint** - Optional network isolation
- ✅ **Network ACLs** - Restrict public access

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| tenant_id | Azure AD tenant ID | string | n/a | yes |
| enable_private_endpoint | Enable private endpoint | bool | false | no |
| subnet_id | Subnet ID for private endpoint | string | null | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| key_vault_id | Key Vault ID |
| key_vault_name | Key Vault name |
| key_vault_uri | Key Vault URI |

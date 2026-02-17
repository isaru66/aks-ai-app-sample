# Networking Module

This module creates the Virtual Network infrastructure for the AKS AI App.

## Resources Created

- Virtual Network (VNet)
- Subnets:
  - AKS subnet for cluster nodes
  - Private endpoints subnet for Azure services
- Network Security Groups (NSGs)
- NSG associations with subnets

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  environment                     = "dev"
  resource_prefix                 = "aks-ai-app-dev"
  vnet_address_space              = ["10.0.0.0/16"]
  aks_subnet_prefix               = "10.0.1.0/24"
  private_endpoints_subnet_prefix = "10.0.2.0/24"
  tags                            = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| vnet_address_space | VNet address space | list(string) | n/a | yes |
| aks_subnet_prefix | AKS subnet prefix | string | n/a | yes |
| private_endpoints_subnet_prefix | Private endpoints subnet prefix | string | n/a | yes |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | Virtual Network ID |
| vnet_name | Virtual Network name |
| aks_subnet_id | AKS subnet ID |
| private_endpoints_subnet_id | Private endpoints subnet ID |

# Monitoring Module

This module creates monitoring infrastructure including Log Analytics and Application Insights.

## Resources Created

- Log Analytics Workspace
- Application Insights (optional)
- Container Insights solution

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  environment                 = "dev"
  resource_prefix             = "aks-ai-app-dev"
  retention_days              = 30
  enable_application_insights = true
  tags                        = local.common_tags
}
```

## Features

- **Log Analytics**: Centralized logging for all Azure resources
- **Application Insights**: APM for backend and frontend applications
- **Container Insights**: AKS monitoring and container logs
- **Adaptive sampling**: Lower sampling in non-production for cost savings

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| retention_days | Log retention in days | number | 30 | no |
| enable_application_insights | Enable Application Insights | bool | true | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| log_analytics_workspace_id | Log Analytics Workspace ID |
| application_insights_connection_string | Application Insights connection string (sensitive) |
| application_insights_instrumentation_key | Application Insights instrumentation key (sensitive) |

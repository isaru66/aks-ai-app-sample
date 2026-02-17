# AI Foundry Module

This module creates Azure AI Foundry Hub and Project resources using the `azurerm` provider.

## Resources Created

- **AI Foundry Hub** (`azurerm_ai_foundry`)
- **AI Foundry Project** (`azurerm_ai_foundry_project`)
- **Role Assignments** for connected services:
  - Azure AI Services access
  - Azure AI Search access
  - Storage access
  - Key Vault access

## What is Azure AI Foundry?

Azure AI Foundry is Microsoft's unified platform for:

- 🤖 **Model Management** - Deploy and manage AI models (OpenAI, OSS models)
- 🔧 **Agent Development** - Build and orchestrate AI agents
- 📊 **Evaluation & Testing** - Red-teaming and quality assurance
- 🔄 **Workflow Orchestration** - Prompt flow and agent workflows
- 📈 **Monitoring** - Centralized telemetry and metrics
- 🔐 **Governance** - RBAC and policy management

## Usage

```hcl
module "ai_foundry" {
  source = "./modules/ai-foundry"

  resource_group_name     = azurerm_resource_group.main.name
  location                = "swedencentral"  # AI services region
  environment             = "dev"
  resource_suffix         = "dev-001"
  random_suffix           = random_string.suffix.result
  ai_services_id          = module.ai_services.ai_services_id
  search_id               = module.ai_services.search_id
  storage_account_id      = module.storage.storage_account_id
  key_vault_id            = module.keyvault.key_vault_id
  application_insights_id = module.monitoring.application_insights_id
  tags                    = local.common_tags
}
```

## Integration with Application

The backend application can use AI Foundry SDK to:

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

# Initialize Foundry client
client = AIProjectClient(
    credential=DefaultAzureCredential(),
    subscription_id="<subscription-id>",
    resource_group_name="<resource-group>",
    project_name="<project-name>"
)

# Access connected AI services
ai_services_connection = client.connections.get("ai-services-connection")

# Deploy models in the project
deployment = client.deployments.create(
    name="gpt-4",
    model="gpt-4",
    sku={"name": "Standard", "capacity": 100}
)

# Create and manage agents
agent = client.agents.create(
    name="chat-agent",
    model="gpt-4",
    instructions="You are a helpful assistant..."
)
```

## Features

- ✅ **Unified Management** - Single pane for all AI resources
- ✅ **Managed Identity** - Secure service-to-service authentication
- ✅ **RBAC Integration** - Role-based access control
- ✅ **Connected Services** - Pre-configured access to AI Services, Search, etc.
- ✅ **Model Deployment** - Deploy OpenAI and OSS models via projects

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_suffix | Suffix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| ai_services_id | Azure AI Services account ID | string | n/a | yes |
| search_id | Azure AI Search ID | string | n/a | yes |
| storage_account_id | Storage account ID | string | n/a | yes |
| key_vault_id | Key Vault ID | string | n/a | yes |
| application_insights_id | Application Insights ID | string | n/a | yes |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| hub_id | AI Foundry Hub ID |
| hub_name | AI Foundry Hub name |
| project_id | AI Foundry Project ID |
| project_name | AI Foundry Project name |
| project_endpoint | AI Foundry Project endpoint |
| hub_principal_id | Managed identity principal ID |

## Additional Resources

- [Azure AI Foundry Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/)
- [Create Hub with Terraform](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/create-resource-terraform)
- [AI Foundry SDK](https://pypi.org/project/azure-ai-projects/)
- [Agent Development Guide](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/develop-agents)

# Quick Start: Azure AI Foundry Deployment

## Overview

This guide helps you deploy the updated infrastructure with Azure AI Foundry.

## Prerequisites

✅ Azure CLI installed and authenticated (`az login`)  
✅ Terraform >= 1.0 installed  
✅ Azure subscription with required permissions  
✅ Existing resource group: `rg-isaru66-aks-terraform-aiapp`  

## Step 1: Review Configuration

### Check Variables

Open `terraform.tfvars` and verify:

```hcl
subscription_id = "79e1d757-ecdb-4dc3-b0b4-035bac76053d"
tenant_id       = "ddcbdc96-6162-4d91-bb0d-066343049ce1"
```

### Regional Configuration

Default regions (configured in `variables.tf`):
- **AI Services**: `swedencentral` (Azure AI Foundry, AI Services, AI Search)
- **Infrastructure**: `southeastasia` (AKS, Storage, Cosmos DB, etc.)

## Step 2: Initialize Terraform

```bash
cd infra/terraform
terraform init -upgrade
```

Expected output:
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- hashicorp/azurerm v4.x
- hashicorp/random v3.x

Terraform has been successfully initialized!
```

## Step 3: Plan Deployment

```bash
terraform plan -out=deploy.tfplan
```

Review the plan output for:
- ✅ Azure AI Services in `swedencentral`
- ✅ Azure AI Foundry Hub in `swedencentral`
- ✅ Azure AI Foundry Project in `swedencentral`
- ✅ Azure AI Search in `swedencentral`
- ✅ Other services in `southeastasia`

## Step 4: Deploy Infrastructure

```bash
terraform apply deploy.tfplan
```

⏱️ **Expected duration**: 15-20 minutes

## Step 5: Verify Deployment

```bash
# Get outputs
terraform output

# Key outputs to note:
# - ai_foundry_project_name
# - ai_foundry_project_endpoint
# - ai_services_endpoint
# - search_endpoint
```

## Step 6: Deploy AI Models

After infrastructure deployment, deploy models via Azure AI Foundry project:

### Option A: Azure Portal

1. Go to [Azure AI Foundry Portal](https://ai.azure.com)
2. Navigate to your project (from `ai_foundry_project_name` output)
3. Click "Deployments" → "Create deployment"
4. Select model (e.g., `gpt-4`, `text-embedding-ada-002`)
5. Configure capacity and create

### Option B: Azure CLI

```bash
# Get project name from terraform output
PROJECT_NAME=$(terraform output -raw ai_foundry_project_name)
RESOURCE_GROUP="rg-isaru66-aks-terraform-aiapp"

# Deploy GPT-4
az ml online-deployment create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $PROJECT_NAME \
  --name gpt-4 \
  --model gpt-4 \
  --sku-name Standard \
  --sku-capacity 100

# Deploy embedding model
az ml online-deployment create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $PROJECT_NAME \
  --name text-embedding-ada-002 \
  --model text-embedding-ada-002 \
  --sku-name Standard \
  --sku-capacity 50
```

### Option C: Python SDK

```bash
# Install SDK
pip install azure-ai-projects azure-identity

# Run deployment script
python scripts/deploy_models.py
```

Example `deploy_models.py`:

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
import os

# Initialize client
client = AIProjectClient(
    credential=DefaultAzureCredential(),
    subscription_id=os.getenv("AZURE_SUBSCRIPTION_ID"),
    resource_group_name="rg-isaru66-aks-terraform-aiapp",
    project_name=os.getenv("AI_FOUNDRY_PROJECT_NAME")
)

# Deploy GPT-4
gpt4_deployment = client.deployments.create(
    name="gpt-4",
    model="gpt-4",
    sku={"name": "Standard", "capacity": 100}
)
print(f"✅ GPT-4 deployed: {gpt4_deployment.name}")

# Deploy embedding model
embedding_deployment = client.deployments.create(
    name="text-embedding-ada-002",
    model="text-embedding-ada-002",
    sku={"name": "Standard", "capacity": 50}
)
print(f"✅ Embedding model deployed: {embedding_deployment.name}")
```

## Step 7: Configure AKS Access

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-isaru66-aks-terraform-aiapp \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes
```

## Step 8: Update Application Configuration

Update your application environment variables:

```bash
# From terraform outputs
export AI_FOUNDRY_PROJECT_ENDPOINT=$(terraform output -raw ai_foundry_project_endpoint)
export AI_SERVICES_ENDPOINT=$(terraform output -raw ai_services_endpoint)
export SEARCH_ENDPOINT=$(terraform output -raw search_endpoint)
export AI_FOUNDRY_PROJECT_NAME=$(terraform output -raw ai_foundry_project_name)

# From Azure
export AZURE_SUBSCRIPTION_ID="79e1d757-ecdb-4dc3-b0b4-035bac76053d"
export AZURE_RESOURCE_GROUP="rg-isaru66-aks-terraform-aiapp"
```

## Troubleshooting

### Issue: Terraform init fails

```bash
# Clear cache and retry
rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
```

### Issue: Resource already exists

```bash
# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>

# Or remove from state
terraform state rm <resource_type>.<resource_name>
```

### Issue: Insufficient permissions

Ensure your account has:
- Contributor role on resource group
- Owner role for RBAC assignments

### Issue: Model deployment fails

Check:
- AI Foundry project exists
- Model is available in the region (`swedencentral`)
- Sufficient quota

## Verification Checklist

- [ ] Terraform apply completed successfully
- [ ] All outputs displayed correctly
- [ ] Azure AI Foundry Hub created in Sweden Central
- [ ] Azure AI Foundry Project created in Sweden Central
- [ ] Azure AI Services created in Sweden Central
- [ ] AKS cluster created in Southeast Asia
- [ ] Models deployed in AI Foundry project
- [ ] kubectl can connect to AKS cluster
- [ ] Application environment variables updated

## Next Steps

1. Deploy backend application to AKS
2. Configure application to use AI Foundry SDK
3. Test AI endpoints
4. Set up monitoring and alerts
5. Configure CI/CD pipeline

## Resources

- [Terraform Documentation](./README.md)
- [Migration Guide](./MIGRATION_TO_AI_FOUNDRY.md)
- [Module Documentation](./modules/)
- [Azure AI Foundry Docs](https://learn.microsoft.com/en-us/azure/ai-foundry/)

## Support

For issues:
1. Check terraform logs: `terraform show`
2. Review Azure Portal for resource status
3. Check module READMEs for specific configuration
4. Refer to MIGRATION_TO_AI_FOUNDRY.md for detailed changes

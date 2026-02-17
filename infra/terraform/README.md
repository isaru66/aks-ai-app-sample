# Terraform Infrastructure

This directory contains Terraform configuration for deploying the Azure AI App infrastructure using **Terraform Workspaces** for multi-environment management.

## 📁 Structure

```
terraform/
├── main.tf              # Main infrastructure orchestration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── providers.tf         # Provider configurations
├── backend.tf           # Azure backend configuration
├── versions.tf          # Version constraints
├── environments/        # Environment-specific tfvars
│   ├── dev.tfvars
│   ├── sit.tfvars
│   ├── uat.tfvars
│   └── production.tfvars
└── modules/            # Reusable modules
    ├── aks/
    ├── acr/
    ├── ai-foundry/
    ├── ai-services/
    ├── cosmosdb/
    ├── storage/
    ├── keyvault/
    ├── networking/
    └── monitoring/
```

## 🚀 Terraform Workspaces

This project uses **Terraform Workspaces** to manage multiple environments with a single codebase:

- **dev** - Development environment
- **sit** - System Integration Testing
- **uat** - User Acceptance Testing
- **production** - Production environment

Each workspace has its own state file, automatically managed by Terraform with the Azure backend.

## 🏗️ Infrastructure Components

### Core Resources

1. **Azure Kubernetes Service (AKS)** - Container orchestration
2. **Azure Container Registry (ACR)** - Docker image storage
3. **Azure AI Foundry** - Unified AI platform
4. **Azure OpenAI (GPT-5.2)** - Large language model
5. **Azure AI Search** - Vector search for RAG
6. **Azure Cosmos DB** - NoSQL database
7. **Azure Storage Account** - Blob storage
8. **Azure Key Vault** - Secrets management
9. **Virtual Network** - Network isolation
10. **Application Insights** - Monitoring and telemetry

## 📋 Prerequisites

- **Azure CLI** installed and authenticated
- **Terraform** >= 1.8.0
- **Azure Subscription** with appropriate permissions
- **Storage Account** for Terraform state (see Backend Setup below)

## 🔧 Backend Setup (One-time)

Before using Terraform, create a storage account for remote state:

```bash
# Variables
RESOURCE_GROUP_NAME="terraform-state-rg"
STORAGE_ACCOUNT_NAME="tfstateaksaiapp"
CONTAINER_NAME="tfstate"
LOCATION="southeastasia"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create storage account
az storage account create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob \
  --location $LOCATION

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME
```

Update `backend.tf` with your storage account details if different.

## 🚦 Usage

### 1. Initialize Terraform

```bash
terraform init
```

This downloads required providers and configures the backend.

### 2. Select/Create Workspace

#### Development Environment

```bash
# Create or select dev workspace
terraform workspace new dev
# or
terraform workspace select dev

# Verify current workspace
terraform workspace show
```

#### Other Environments

```bash
terraform workspace new sit
terraform workspace new uat
terraform workspace new production
```

### 3. Configure Environment Variables

Edit the appropriate `.tfvars` file in `environments/`:

```bash
# Example: Edit dev environment
nano environments/dev.tfvars
```

**Required variables:**
- `subscription_id` - Your Azure subscription ID
- `tenant_id` - Your Azure AD tenant ID

### 4. Plan Infrastructure

```bash
# Plan dev environment
terraform plan -var-file="environments/dev.tfvars"

# Plan production environment
terraform workspace select production
terraform plan -var-file="environments/production.tfvars"
```

### 5. Apply Infrastructure

```bash
# Apply dev environment
terraform workspace select dev
terraform apply -var-file="environments/dev.tfvars"

# Apply with auto-approve (for CI/CD)
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

### 6. View Outputs

```bash
# Show all outputs
terraform output

# Show specific output
terraform output aks_cluster_name

# Export outputs to JSON
terraform output -json > outputs.json
```

### 7. Destroy Infrastructure (if needed)

```bash
terraform workspace select dev
terraform destroy -var-file="environments/dev.tfvars"
```

## 📝 Environment Configuration

### Development (dev.tfvars)

- **Purpose**: Local development and testing
- **AKS Nodes**: 2-5 nodes (Standard_D4s_v3)
- **GPT-5.2 Capacity**: 50 TPM/1000
- **Search SKU**: Basic
- **Storage Replication**: LRS
- **Private Endpoints**: Disabled (cost savings)

### SIT (sit.tfvars)

- **Purpose**: System integration testing
- **AKS Nodes**: 3-8 nodes (Standard_D4s_v3)
- **GPT-5.2 Capacity**: 80 TPM/1000
- **Search SKU**: Standard
- **Storage Replication**: GRS
- **Private Endpoints**: Disabled

### UAT (uat.tfvars)

- **Purpose**: User acceptance testing
- **AKS Nodes**: 3-10 nodes (Standard_D8s_v3)
- **GPT-5.2 Capacity**: 100 TPM/1000
- **Search SKU**: Standard (2 replicas)
- **Storage Replication**: GRS
- **Private Endpoints**: Enabled

### Production (production.tfvars)

- **Purpose**: Production workloads
- **AKS Nodes**: 5-20 nodes (Standard_D8s_v3)
- **GPT-5.2 Capacity**: 200 TPM/1000
- **Search SKU**: Standard (3 replicas, 2 partitions)
- **Storage Replication**: GZRS
- **Private Endpoints**: Enabled (required)
- **Private Cluster**: Enabled

## 🔍 Common Commands

```bash
# List all workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Show state
terraform show

# Refresh state
terraform refresh -var-file="environments/dev.tfvars"

# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/{sub-id}/resourceGroups/{rg-name}
```

## 🔐 Security Best Practices

1. **Never commit `.tfvars` files with sensitive data** to version control
2. **Use Azure Key Vault** for all secrets
3. **Enable private endpoints** for production
4. **Use managed identities** instead of service principals where possible
5. **Enable soft delete** for Key Vault and storage
6. **Review IAM permissions** regularly

## 🧪 Testing Changes

Before applying to production:

1. Test in **dev** environment
2. Promote to **sit** for integration testing
3. Promote to **uat** for user testing
4. Finally deploy to **production**

```bash
# Test workflow
terraform workspace select dev
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
# ... verify changes ...

terraform workspace select production
terraform plan -var-file="environments/production.tfvars"
terraform apply -var-file="environments/production.tfvars"
```

## 📊 State Management

State files are stored in Azure Storage with workspace isolation:

```
Container: tfstate
├── env:/dev/aks-ai-app.tfstate
├── env:/sit/aks-ai-app.tfstate
├── env:/uat/aks-ai-app.tfstate
└── env:/production/aks-ai-app.tfstate
```

Each workspace maintains its own state, preventing conflicts.

## 🐛 Troubleshooting

### Workspace Not Found

```bash
terraform workspace new <environment>
```

### State Lock Issues

```bash
# If state is locked, force unlock (use carefully!)
terraform force-unlock <lock-id>
```

### Provider Authentication

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Verify
az account show
```

### Module Changes Not Detected

```bash
# Reinitialize to update modules
terraform init -upgrade
```

## 📚 Additional Resources

- [Terraform Workspaces Documentation](https://www.terraform.io/docs/language/state/workspaces.html)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 🤝 Contributing

When adding new resources:

1. Create/update modules in `modules/`
2. Update `variables.tf` with new variables
3. Update all `.tfvars` files with appropriate values
4. Update `outputs.tf` if new outputs needed
5. Test in dev workspace before other environments
6. Update this README

---

**Note**: Always run `terraform plan` before `terraform apply` to review changes!

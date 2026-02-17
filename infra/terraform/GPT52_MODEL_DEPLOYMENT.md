# GPT-5.2 Model Deployment in AI Foundry

## Summary

Added GPT-5.2 and text-embedding-ada-002 model deployments to the AI Foundry module using `azurerm_cognitive_deployment` resources.

## Models Deployed

### 1. GPT-5.2 (Latest Model)

```hcl
resource "azurerm_cognitive_deployment" "gpt52" {
  name                 = "gpt-5.2"
  cognitive_account_id = var.ai_services_id

  model {
    format  = "OpenAI"
    name    = "gpt-5.2"
    version = "2025-12-11"  # Latest version
  }

  sku {
    name     = "GlobalStandard"
    capacity = 500  # 500K TPM (Tokens Per Minute)
  }

  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  rai_policy_name        = "Microsoft.DefaultV2"
}
```

### 2. Text-Embedding-Ada-002 (for RAG)

```hcl
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-ada-002"
  cognitive_account_id = var.ai_services_id

  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  sku {
    name     = "Standard"
    capacity = 100  # 100K TPM
  }
}
```

## Configuration Variables

### New Variables Added

**Root `variables.tf`:**
```hcl
variable "deploy_gpt_model" {
  description = "Deploy GPT-5.2 model"
  type        = bool
  default     = true
}

variable "gpt_model_capacity" {
  description = "GPT-5.2 model capacity (TPM in thousands)"
  type        = number
  default     = 500
}

variable "deploy_embedding_model" {
  description = "Deploy text-embedding-ada-002 model"
  type        = bool
  default     = true
}

variable "embedding_model_capacity" {
  description = "Embedding model capacity (TPM in thousands)"
  type        = number
  default     = 100
}
```

## Usage

### Enable/Disable Model Deployments

**Deploy Both Models (Default):**
```hcl
# environments/dev.tfvars
deploy_gpt_model       = true
gpt_model_capacity     = 500
deploy_embedding_model = true
embedding_model_capacity = 100
```

**Deploy Only GPT-5.2:**
```hcl
deploy_gpt_model       = true
deploy_embedding_model = false  # Skip embedding model
```

**Deploy Only Embedding:**
```hcl
deploy_gpt_model       = false  # Skip GPT
deploy_embedding_model = true
```

**Skip All Deployments:**
```hcl
deploy_gpt_model       = false
deploy_embedding_model = false
```

### Adjust Capacity by Environment

**Development (Lower Capacity):**
```hcl
# environments/dev.tfvars
gpt_model_capacity       = 100  # 100K TPM
embedding_model_capacity = 50   # 50K TPM
```

**Production (Higher Capacity):**
```hcl
# environments/production.tfvars
gpt_model_capacity       = 1000  # 1M TPM
embedding_model_capacity = 500   # 500K TPM
```

## Model Specifications

### GPT-5.2

**Capabilities:**
- ✅ **Extended Thinking** - Visible reasoning process
- ✅ **Large Context** - Up to 1M+ tokens
- ✅ **Multimodal** - Text, images, audio
- ✅ **Function Calling** - Tool integration
- ✅ **Streaming** - Real-time responses
- ✅ **JSON Mode** - Structured outputs

**SKU: GlobalStandard**
- Deployed globally with automatic routing
- Best latency for users worldwide
- Dynamic capacity allocation

**Capacity:**
- Measured in TPM (Tokens Per Minute)
- Default: 500 = 500,000 TPM
- Adjustable based on load

**Version: 2025-12-11**
- Latest stable version
- Auto-upgrade enabled with `OnceNewDefaultVersionAvailable`

### Text-Embedding-Ada-002

**Capabilities:**
- ✅ **Vector Embeddings** - Convert text to vectors
- ✅ **Semantic Search** - Find similar content
- ✅ **RAG Support** - Retrieval-augmented generation
- ✅ **1536 Dimensions** - High-quality embeddings

**SKU: Standard**
- Regional deployment
- Fixed capacity allocation

**Capacity:**
- Default: 100 = 100,000 TPM
- Sufficient for most RAG use cases

## Outputs

### Module Outputs

```hcl
output "gpt52_deployment_name" {
  value = "gpt-5.2"
}

output "gpt52_model_version" {
  value = "2025-12-11"
}

output "embedding_deployment_name" {
  value = "text-embedding-ada-002"
}
```

### Root Outputs

```hcl
output "ai_foundry_gpt52_deployment" {
  value = module.ai_foundry[0].gpt52_deployment_name
}

output "ai_foundry_embedding_deployment" {
  value = module.ai_foundry[0].embedding_deployment_name
}
```

## Application Integration

### Using GPT-5.2

**Python:**
```python
from openai import AzureOpenAI

client = AzureOpenAI(
    api_key=os.getenv("AZURE_AI_SERVICES_API_KEY"),
    api_version="2024-10-01",
    azure_endpoint=os.getenv("AZURE_AI_SERVICES_ENDPOINT")
)

response = client.chat.completions.create(
    model="gpt-5.2",  # Deployment name
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"}
    ],
    stream=True,
    stream_options={
        "include_reasoning": True  # Show thinking process
    }
)
```

### Using Embeddings

**Python:**
```python
response = client.embeddings.create(
    model="text-embedding-ada-002",  # Deployment name
    input="Your text to embed"
)

embedding = response.data[0].embedding  # 1536 dimensions
```

## Cost Estimation

### GPT-5.2 Pricing

- **Base Cost:** ~$15-30/1M tokens (input)
- **Output Cost:** ~$60-120/1M tokens
- **Capacity:** 500K TPM = ~$100-500/month (depends on usage)

### Text-Embedding-Ada-002 Pricing

- **Cost:** ~$0.10/1M tokens
- **Capacity:** 100K TPM = ~$10-50/month (depends on usage)

**Total Estimated Cost:**
- Development: ~$50-200/month
- Production: ~$200-1,000/month

## Files Modified

```
infra/terraform/
├── variables.tf                           (added model deployment vars)
├── main.tf                                (pass vars to ai_foundry module)
├── outputs.tf                             (added model deployment outputs)
├── environments/dev.tfvars                (added model settings)
└── modules/ai-foundry/
    ├── main.tf                            (added cognitive deployments)
    ├── variables.tf                       (added model deployment vars)
    └── outputs.tf                         (added deployment outputs)
```

## Deployment Verification

After `terraform apply`, verify deployments:

```bash
# Get deployment names
terraform output ai_foundry_gpt52_deployment
terraform output ai_foundry_embedding_deployment

# Check via Azure CLI
RESOURCE_GROUP="rg-isaru66-aks-terraform-aiapp"
AI_SERVICES_NAME=$(terraform output -raw ai_services_name)

az cognitiveservices account deployment list \
  --resource-group $RESOURCE_GROUP \
  --name $AI_SERVICES_NAME \
  --query "[].{name:name, model:properties.model.name, capacity:sku.capacity}"
```

Expected output:
```json
[
  {
    "name": "gpt-5.2",
    "model": "gpt-5.2",
    "capacity": 500
  },
  {
    "name": "text-embedding-ada-002",
    "model": "text-embedding-ada-002",
    "capacity": 100
  }
]
```

## Testing Models

### Test GPT-5.2

```bash
# Using Azure CLI
az cognitiveservices account deployment show \
  --resource-group $RESOURCE_GROUP \
  --name $AI_SERVICES_NAME \
  --deployment-name gpt-5.2
```

### Test with API Call

```python
import os
from openai import AzureOpenAI

client = AzureOpenAI(
    api_key=os.getenv("AZURE_AI_SERVICES_API_KEY"),
    api_version="2024-10-01",
    azure_endpoint=os.getenv("AZURE_AI_SERVICES_ENDPOINT")
)

# Test GPT-5.2
response = client.chat.completions.create(
    model="gpt-5.2",
    messages=[{"role": "user", "content": "Say hello!"}]
)
print(response.choices[0].message.content)

# Test embeddings
embedding_response = client.embeddings.create(
    model="text-embedding-ada-002",
    input="Test embedding"
)
print(f"Embedding dimensions: {len(embedding_response.data[0].embedding)}")
```

## Advanced Configuration

### Capacity Planning

**Low Traffic (Dev):**
```hcl
gpt_model_capacity       = 100   # 100K TPM
embedding_model_capacity = 50    # 50K TPM
```

**Medium Traffic (UAT):**
```hcl
gpt_model_capacity       = 500   # 500K TPM
embedding_model_capacity = 200   # 200K TPM
```

**High Traffic (Production):**
```hcl
gpt_model_capacity       = 1000  # 1M TPM
embedding_model_capacity = 500   # 500K TPM
```

### Version Upgrade Options

```hcl
version_upgrade_option = "OnceNewDefaultVersionAvailable"  # Default
# or
version_upgrade_option = "OnceCurrentVersionExpired"       # Manual control
# or
version_upgrade_option = "NoAutoUpgrade"                   # Never auto-upgrade
```

## Benefits

1. ✅ **Automated Deployment** - Models deployed with infrastructure
2. ✅ **Version Control** - Model versions tracked in Terraform
3. ✅ **Reproducible** - Same setup across environments
4. ✅ **Configurable Capacity** - Adjust by environment
5. ✅ **Auto-Upgrade** - Latest model versions automatically

## Limitations

### Quota Requirements

Ensure you have quota in the region (swedencentral) for:
- GPT-5.2: 500K TPM minimum
- text-embedding-ada-002: 100K TPM minimum

Check quota:
```bash
az cognitiveservices account list-skus \
  --location swedencentral \
  --kind OpenAI
```

### Model Availability

GPT-5.2 must be available in `swedencentral` region. If not:

```hcl
# Use different region for AI services
ai_location = "eastus"  # or other region with GPT-5.2
```

## References

- [azurerm_cognitive_deployment Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment)
- [Azure OpenAI Models](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models)
- [GPT-5.2 Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/gpt-5-2)

# Populate .env from Terraform Outputs

## Quick Start

After deploying infrastructure with Terraform, run this script to automatically populate your `.env` file:

### PowerShell (Windows)

```powershell
.\scripts\populate-env-from-terraform.ps1
```

### Bash (Linux/Mac)

```bash
chmod +x scripts/populate-env-from-terraform.sh
./scripts/populate-env-from-terraform.sh
```

## What It Does

The script:
1. ✅ Reads all Terraform outputs
2. ✅ Populates `.env` with actual values
3. ✅ Includes sensitive values (App Insights connection string)
4. ✅ Marks fields that need manual updates

## Values Populated Automatically

| Variable | Source |
|----------|--------|
| `AZURE_SUBSCRIPTION_ID` | Terraform output |
| `AZURE_TENANT_ID` | Terraform output |
| `AZURE_AI_FOUNDRY_ENDPOINT` | Terraform output |
| `AZURE_AI_FOUNDRY_PROJECT_NAME` | Terraform output |
| `AZURE_AI_FOUNDRY_HUB_NAME` | Terraform output |
| `AZURE_AI_SERVICES_ENDPOINT` | Terraform output |
| `AZURE_AI_SERVICES_NAME` | Terraform output |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Terraform output (gpt-5.2) |
| `AZURE_OPENAI_EMBEDDING_DEPLOYMENT` | Terraform output |
| `AZURE_STORAGE_ACCOUNT_NAME` | Terraform output |
| `AZURE_STORAGE_ENDPOINT` | Terraform output |
| `AZURE_KEY_VAULT_URL` | Terraform output |
| `AZURE_KEY_VAULT_NAME` | Terraform output |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Terraform output |
| `AKS_CLUSTER_NAME` | Terraform output |
| `AKS_RESOURCE_GROUP` | Terraform output |
| `ACR_NAME` | Terraform output |
| `ACR_LOGIN_SERVER` | Terraform output |
| `AZURE_SEARCH_ENDPOINT` | Terraform output (if enabled) |
| `AZURE_COSMOSDB_ENDPOINT` | Terraform output (if enabled) |

## Manual Steps Required

After running the script, you need to manually update:

### 1. Get AI Services API Key

```bash
# Get the API key from Azure
az cognitiveservices account keys list \
  --name ai-isaru66-aiapp-asse-001 \
  --resource-group rg-isaru66-aks-terraform-aiapp \
  --query key1 -o tsv

# Update in .env
AZURE_AI_SERVICES_API_KEY=<paste-key-here>
AZURE_OPENAI_API_KEY=<paste-same-key-here>
```

### 2. Get Keys from Key Vault (Optional)

If using Key Vault for secrets:

```bash
KEY_VAULT_NAME="kvisaru66aiappasse001"

# Get AI Services key
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name azure-ai-services-api-key \
  --query value -o tsv

# Get Search key (if enabled)
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name azure-search-api-key \
  --query value -o tsv

# Get Cosmos DB key (if enabled)
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name azure-cosmosdb-key \
  --query value -o tsv
```

### 3. Generate JWT Secret

```bash
# Generate secure JWT secret
openssl rand -hex 32

# Or in PowerShell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))

# Update in .env
JWT_SECRET_KEY=<paste-generated-key>
```

### 4. Update Client Credentials (If Using Service Principal)

```bash
# If you're using Azure Service Principal authentication
AZURE_CLIENT_ID=<your-app-registration-client-id>
AZURE_CLIENT_SECRET=<your-app-registration-secret>
```

## One-Liner to Get All Keys

```bash
# Set variables
KEY_VAULT_NAME="kvisaru66aiappasse001"
AI_SERVICES_NAME="ai-isaru66-aiapp-asse-001"
RESOURCE_GROUP="rg-isaru66-aks-terraform-aiapp"

# Get all keys at once
echo "AI Services Key:"
az cognitiveservices account keys list \
  --name $AI_SERVICES_NAME \
  --resource-group $RESOURCE_GROUP \
  --query key1 -o tsv

echo ""
echo "JWT Secret (generate new):"
openssl rand -hex 32
```

## After Populating .env

### Test Configuration

```bash
# Test backend connection
cd backend
source ../.env  # Or: export $(cat ../.env | xargs)
python -c "import os; print('AI Endpoint:', os.getenv('AZURE_AI_SERVICES_ENDPOINT'))"
```

### Start Services

```bash
# Start backend
cd backend
python -m uvicorn main:app --reload

# Start frontend (new terminal)
cd frontend
npm run dev
```

## Alternative: Use Key Vault References

Instead of putting secrets in `.env`, use Key Vault:

```python
# backend code
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url=os.getenv("AZURE_KEY_VAULT_URL"),
    credential=credential
)

# Get secrets from Key Vault
ai_services_key = client.get_secret("azure-ai-services-api-key").value
```

## Troubleshooting

### Script Fails

**Error: "terraform: command not found"**
- Install Terraform: https://www.terraform.io/downloads

**Error: "No terraform outputs found"**
- Run `terraform apply` first to create resources

**Error: "Permission denied"**
```bash
chmod +x scripts/populate-env-from-terraform.sh
```

### Empty Values in .env

**Cause:** Module might be disabled or not created yet.

**Solution:** 
1. Check terraform outputs: `terraform output`
2. Enable required modules in tfvars
3. Run `terraform apply`
4. Re-run the populate script

## Benefits

1. ✅ **Automated** - No manual copy/paste
2. ✅ **Accurate** - Values directly from infrastructure
3. ✅ **Fast** - Updates in seconds
4. ✅ **Consistent** - Same values across team
5. ✅ **Reproducible** - Easy to regenerate

## See Also

- `.env.example` - Template with all variables
- `infra/terraform/outputs.tf` - All available outputs
- Application documentation for environment variables

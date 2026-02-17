#!/bin/bash
# Script to populate .env file from Terraform outputs
# Run from project root: ./scripts/populate-env-from-terraform.sh

set -e

echo "🔧 Populating .env from Terraform outputs..."

# Check if terraform directory exists
if [ ! -d "infra/terraform" ]; then
    echo "❌ Error: infra/terraform directory not found"
    echo "Run this script from the project root directory"
    exit 1
fi

# Change to terraform directory
cd infra/terraform

# Get terraform outputs
echo "📊 Reading Terraform outputs..."

subscription_id=$(terraform output -raw subscription_id 2>/dev/null || echo "")
tenant_id=$(terraform output -raw tenant_id 2>/dev/null || echo "")
ai_services_endpoint=$(terraform output -raw ai_services_endpoint 2>/dev/null || echo "")
ai_services_name=$(terraform output -raw ai_services_name 2>/dev/null || echo "")
ai_foundry_project_endpoint=$(terraform output -raw ai_foundry_project_endpoint 2>/dev/null || echo "")
ai_foundry_project_name=$(terraform output -raw ai_foundry_project_name 2>/dev/null || echo "")
ai_foundry_project_id=$(terraform output -raw ai_foundry_project_id 2>/dev/null || echo "")
ai_foundry_hub_name=$(terraform output -raw ai_foundry_hub_name 2>/dev/null || echo "")
gpt52_deployment=$(terraform output -raw ai_foundry_gpt52_deployment 2>/dev/null || echo "gpt-5.2")
embedding_deployment=$(terraform output -raw ai_foundry_embedding_deployment 2>/dev/null || echo "text-embedding-ada-002")
storage_account_name=$(terraform output -raw storage_account_name 2>/dev/null || echo "")
storage_blob_endpoint=$(terraform output -raw storage_account_primary_blob_endpoint 2>/dev/null || echo "")
key_vault_uri=$(terraform output -raw key_vault_uri 2>/dev/null || echo "")
key_vault_name=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
aks_cluster_name=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
resource_group=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
acr_name=$(terraform output -raw acr_name 2>/dev/null || echo "")
acr_login_server=$(terraform output -raw acr_login_server 2>/dev/null || echo "")
search_endpoint=$(terraform output -raw search_endpoint 2>/dev/null || echo "not-deployed")
cosmosdb_endpoint=$(terraform output -raw cosmosdb_endpoint 2>/dev/null || echo "not-deployed")

# Get sensitive values
echo "🔐 Reading sensitive outputs..."
app_insights_conn_string=$(terraform output -raw application_insights_connection_string 2>/dev/null || echo "")

cd ../..

# Create .env file
cat > .env << EOF
# Azure Configuration
AZURE_SUBSCRIPTION_ID=$subscription_id
AZURE_TENANT_ID=$tenant_id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

# Environment
ENVIRONMENT=dev

# Azure AI Foundry
AZURE_AI_FOUNDRY_ENDPOINT=$ai_foundry_project_endpoint
AZURE_AI_FOUNDRY_PROJECT_NAME=$ai_foundry_project_name
AZURE_AI_FOUNDRY_PROJECT_ID=$ai_foundry_project_id
AZURE_AI_FOUNDRY_HUB_NAME=$ai_foundry_hub_name

# Azure AI Services (replaces OpenAI)
AZURE_AI_SERVICES_ENDPOINT=$ai_services_endpoint
AZURE_AI_SERVICES_NAME=$ai_services_name
AZURE_AI_SERVICES_API_KEY=get-from-keyvault
# Get key: az cognitiveservices account keys list --name $ai_services_name --resource-group $resource_group --query key1 -o tsv

# Azure OpenAI Model Deployments
AZURE_OPENAI_ENDPOINT=$ai_services_endpoint
AZURE_OPENAI_API_KEY=get-from-keyvault
AZURE_OPENAI_DEPLOYMENT_NAME=$gpt52_deployment
AZURE_OPENAI_API_VERSION=2024-10-01
AZURE_OPENAI_MODEL=gpt-5.2
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=$embedding_deployment

# Azure AI Search (disabled by default)
AZURE_SEARCH_ENDPOINT=$search_endpoint
AZURE_SEARCH_API_KEY=get-from-keyvault-if-enabled
AZURE_SEARCH_INDEX_NAME=documents

# Azure Cosmos DB (disabled by default)
AZURE_COSMOSDB_ENDPOINT=$cosmosdb_endpoint
AZURE_COSMOSDB_KEY=get-from-keyvault-if-enabled
AZURE_COSMOSDB_DATABASE_NAME=chatdb
AZURE_COSMOSDB_CONTAINER_NAME=conversations

# Azure Storage (uses Azure AD authentication, no key)
AZURE_STORAGE_ACCOUNT_NAME=$storage_account_name
AZURE_STORAGE_ENDPOINT=$storage_blob_endpoint
AZURE_STORAGE_CONTAINER_NAME=documents

# Azure Key Vault
AZURE_KEY_VAULT_URL=$key_vault_uri
AZURE_KEY_VAULT_NAME=$key_vault_name

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING=$app_insights_conn_string

# AKS Configuration
AKS_CLUSTER_NAME=$aks_cluster_name
AKS_RESOURCE_GROUP=$resource_group

# ACR Configuration
ACR_NAME=$acr_name
ACR_LOGIN_SERVER=$acr_login_server

# Backend Configuration
BACKEND_PORT=8000
BACKEND_HOST=0.0.0.0
LOG_LEVEL=INFO
CORS_ORIGINS=http://localhost:3000,https://your-domain.com

# Frontend Configuration
NEXT_PUBLIC_API_URL=http://localhost:8000/api
NEXT_PUBLIC_APP_NAME=Azure AI Chat App
NEXT_PUBLIC_ENABLE_THINKING_DISPLAY=true

# Feature Flags
ENABLE_STREAMING=true
ENABLE_THINKING_PROCESS=true
ENABLE_RAG=false
ENABLE_AGENTS=true

# Redis (Optional)
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=your-redis-password

# Authentication
JWT_SECRET_KEY=your-jwt-secret-key-change-this
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=60
EOF

    echo "✅ .env file created successfully!"
    echo ""
    echo "📝 Manual steps required:"
    echo "1. Get AI Services API key:"
    echo "   az cognitiveservices account keys list --name $ai_services_name --resource-group $resource_group --query key1 -o tsv"
    echo ""
    echo "2. Update these values in .env:"
    echo "   - AZURE_CLIENT_ID (if using service principal)"
    echo "   - AZURE_CLIENT_SECRET (if using service principal)"
    echo "   - JWT_SECRET_KEY (generate: openssl rand -hex 32)"
    echo ""
    echo "3. For Search and Cosmos DB keys (if enabled):"
    echo "   az keyvault secret show --vault-name $key_vault_name --name azure-search-api-key --query value -o tsv"
    echo "   az keyvault secret show --vault-name $key_vault_name --name azure-cosmosdb-key --query value -o tsv"
    echo ""
    echo "🎉 Done! Review and update .env as needed."

} catch {
    echo "❌ Error creating .env file"
    exit 1
}

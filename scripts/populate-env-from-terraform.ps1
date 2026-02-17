#!/usr/bin/env pwsh
# Script to populate .env file from Terraform outputs
# Run from project root: ./scripts/populate-env-from-terraform.ps1

$ErrorActionPreference = "Stop"

Write-Host "🔧 Populating .env from Terraform outputs..." -ForegroundColor Cyan

# Check if terraform directory exists
if (-not (Test-Path "infra/terraform")) {
    Write-Host "❌ Error: infra/terraform directory not found" -ForegroundColor Red
    Write-Host "Run this script from the project root directory" -ForegroundColor Yellow
    exit 1
}

# Change to terraform directory
Push-Location infra/terraform

try {
    # Get terraform outputs
    Write-Host "📊 Reading Terraform outputs..." -ForegroundColor Yellow
    
    $subscription_id = (terraform output -raw subscription_id 2>$null) 
    $tenant_id = (terraform output -raw tenant_id 2>$null)
    $ai_services_endpoint = (terraform output -raw ai_services_endpoint 2>$null)
    $ai_services_name = (terraform output -raw ai_services_name 2>$null)
    $ai_foundry_project_endpoint = (terraform output -raw ai_foundry_project_endpoint 2>$null)
    $ai_foundry_project_name = (terraform output -raw ai_foundry_project_name 2>$null)
    $ai_foundry_project_id = (terraform output -raw ai_foundry_project_id 2>$null)
    $ai_foundry_hub_name = (terraform output -raw ai_foundry_hub_name 2>$null)
    $gpt52_deployment = (terraform output -raw ai_foundry_gpt52_deployment 2>$null)
    $embedding_deployment = (terraform output -raw ai_foundry_embedding_deployment 2>$null)
    $storage_account_name = (terraform output -raw storage_account_name 2>$null)
    $storage_blob_endpoint = (terraform output -raw storage_account_primary_blob_endpoint 2>$null)
    $key_vault_uri = (terraform output -raw key_vault_uri 2>$null)
    $key_vault_name = (terraform output -raw key_vault_name 2>$null)
    $aks_cluster_name = (terraform output -raw aks_cluster_name 2>$null)
    $resource_group = (terraform output -raw resource_group_name 2>$null)
    $acr_name = (terraform output -raw acr_name 2>$null)
    $acr_login_server = (terraform output -raw acr_login_server 2>$null)
    $search_endpoint = (terraform output -raw search_endpoint 2>$null)
    $cosmosdb_endpoint = (terraform output -raw cosmosdb_endpoint 2>$null)
    
    # Get sensitive values
    Write-Host "🔐 Reading sensitive outputs..." -ForegroundColor Yellow
    $app_insights_conn_string = (terraform output -raw application_insights_connection_string 2>$null)
    
} catch {
    Write-Host "❌ Error reading Terraform outputs: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

# Create .env file content
$envContent = @"
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
# Get key: az cognitiveservices account keys list --name $ai_services_name --resource-group $resource_group

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
"@

# Write to .env file
try {
    $envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline
    Write-Host "✅ .env file updated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Manual steps required:" -ForegroundColor Yellow
    Write-Host "1. Get AI Services API key:" -ForegroundColor White
    Write-Host "   az cognitiveservices account keys list --name $ai_services_name --resource-group $resource_group --query key1 -o tsv" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Update these values in .env:" -ForegroundColor White
    Write-Host "   - AZURE_CLIENT_ID (if using service principal)" -ForegroundColor Gray
    Write-Host "   - AZURE_CLIENT_SECRET (if using service principal)" -ForegroundColor Gray
    Write-Host "   - JWT_SECRET_KEY (generate a secure key)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. For Search and Cosmos DB keys (if enabled):" -ForegroundColor White
    Write-Host "   az keyvault secret show --vault-name $key_vault_name --name azure-search-api-key --query value -o tsv" -ForegroundColor Gray
    Write-Host "   az keyvault secret show --vault-name $key_vault_name --name azure-cosmosdb-key --query value -o tsv" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error writing .env file: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Done! Review and update .env as needed." -ForegroundColor Green

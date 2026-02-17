#!/bin/bash

# Deployment Script for Azure AI Chat Application
# Usage: ./scripts/deploy.sh <environment> <action>
# Example: ./scripts/deploy.sh dev apply

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infra/terraform"
HELM_DIR="$PROJECT_ROOT/infra/helm/ai-app"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    commands=("az" "terraform" "kubectl" "helm")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed"
            exit 1
        fi
    done
    
    log_info "All prerequisites met ✓"
}

# Deploy infrastructure
deploy_infrastructure() {
    local env=$1
    local action=$2
    
    log_info "Deploying infrastructure for environment: $env"
    
    cd "$TERRAFORM_DIR/environments/$env"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Select or create workspace
    terraform workspace select $env 2>/dev/null || terraform workspace new $env
    
    # Plan
    if [ "$action" = "plan" ]; then
        terraform plan -var-file="${env}.tfvars"
        return
    fi
    
    # Apply
    if [ "$action" = "apply" ]; then
        terraform apply -var-file="${env}.tfvars" -auto-approve
        
        # Get outputs
        log_info "Getting Terraform outputs..."
        AKS_NAME=$(terraform output -raw aks_name)
        RESOURCE_GROUP=$(terraform output -raw resource_group_name)
        ACR_NAME=$(terraform output -raw acr_name)
        
        # Save outputs
        cat > "$PROJECT_ROOT/.env.$env" <<EOF
AKS_NAME=$AKS_NAME
RESOURCE_GROUP=$RESOURCE_GROUP
ACR_NAME=$ACR_NAME
EOF
        
        log_info "Infrastructure deployed successfully ✓"
    fi
    
    # Destroy
    if [ "$action" = "destroy" ]; then
        log_warn "This will destroy all infrastructure!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            terraform destroy -var-file="${env}.tfvars" -auto-approve
            log_info "Infrastructure destroyed ✓"
        fi
    fi
}

# Build and push images
build_and_push() {
    local env=$1
    
    log_info "Building and pushing Docker images..."
    
    # Load environment variables
    source "$PROJECT_ROOT/.env.$env"
    
    # Login to ACR
    az acr login --name $ACR_NAME
    
    # Build backend
    log_info "Building backend image..."
    docker build -t ${ACR_NAME}.azurecr.io/backend:latest \
        -t ${ACR_NAME}.azurecr.io/backend:$(git rev-parse --short HEAD) \
        "$PROJECT_ROOT/backend"
    
    # Build frontend
    log_info "Building frontend image..."
    docker build -t ${ACR_NAME}.azurecr.io/frontend:latest \
        -t ${ACR_NAME}.azurecr.io/frontend:$(git rev-parse --short HEAD) \
        "$PROJECT_ROOT/frontend"
    
    # Push images
    log_info "Pushing images to ACR..."
    docker push ${ACR_NAME}.azurecr.io/backend:latest
    docker push ${ACR_NAME}.azurecr.io/backend:$(git rev-parse --short HEAD)
    docker push ${ACR_NAME}.azurecr.io/frontend:latest
    docker push ${ACR_NAME}.azurecr.io/frontend:$(git rev-parse --short HEAD)
    
    log_info "Images pushed successfully ✓"
}

# Deploy application
deploy_application() {
    local env=$1
    
    log_info "Deploying application to environment: $env"
    
    # Load environment variables
    source "$PROJECT_ROOT/.env.$env"
    
    # Get AKS credentials
    log_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_NAME \
        --overwrite-existing
    
    # Install Envoy Gateway if not exists
    if ! kubectl get namespace envoy-gateway-system &> /dev/null; then
        log_info "Installing Envoy Gateway..."
        helm install eg oci://docker.io/envoyproxy/gateway-helm \
            --version v1.0.0 \
            -n envoy-gateway-system \
            --create-namespace
        
        # Wait for Envoy Gateway
        kubectl wait --for=condition=available \
            --timeout=300s \
            deployment/envoy-gateway \
            -n envoy-gateway-system
    fi
    
    # Create namespace if not exists
    kubectl create namespace ai-app-$env --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ACR secret
    log_info "Creating ACR secret..."
    kubectl create secret docker-registry acr-secret \
        --docker-server=${ACR_NAME}.azurecr.io \
        --docker-username=$ACR_NAME \
        --docker-password=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv) \
        --namespace=ai-app-$env \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy with Helm
    log_info "Deploying with Helm..."
    helm upgrade ai-app $HELM_DIR \
        --install \
        --namespace ai-app-$env \
        --values $HELM_DIR/values.yaml \
        --values $HELM_DIR/environments/${env}-values.yaml \
        --set backend.image.repository=${ACR_NAME}.azurecr.io/backend \
        --set frontend.image.repository=${ACR_NAME}.azurecr.io/frontend \
        --wait \
        --timeout 10m
    
    log_info "Application deployed successfully ✓"
    
    # Get Gateway IP
    log_info "Getting Gateway IP..."
    kubectl get gateway ai-app-gateway -n ai-app-$env
    
    log_info "Deployment complete! ✓"
}

# Rollback application
rollback_application() {
    local env=$1
    local revision=${2:-0}
    
    log_info "Rolling back application in environment: $env"
    
    helm rollback ai-app $revision --namespace ai-app-$env
    
    log_info "Rollback complete ✓"
}

# Main script
main() {
    local env=$1
    local action=$2
    
    # Validate arguments
    if [ -z "$env" ] || [ -z "$action" ]; then
        log_error "Usage: $0 <environment> <action>"
        log_error "Environments: dev, sit, uat, prod"
        log_error "Actions: plan, apply, destroy, deploy, rollback"
        exit 1
    fi
    
    # Validate environment
    if [[ ! "$env" =~ ^(dev|sit|uat|prod)$ ]]; then
        log_error "Invalid environment: $env"
        exit 1
    fi
    
    log_info "Starting deployment process..."
    log_info "Environment: $env"
    log_info "Action: $action"
    
    check_prerequisites
    
    case $action in
        plan|apply|destroy)
            deploy_infrastructure $env $action
            ;;
        build)
            build_and_push $env
            ;;
        deploy)
            build_and_push $env
            deploy_application $env
            ;;
        app-only)
            deploy_application $env
            ;;
        rollback)
            rollback_application $env $3
            ;;
        *)
            log_error "Invalid action: $action"
            exit 1
            ;;
    esac
    
    log_info "All done! 🎉"
}

# Run main
main "$@"

.PHONY: help init plan apply destroy clean test dev up down logs

# Variables
TERRAFORM_DIR := infra/terraform
HELM_DIR := infra/helm/ai-app
BACKEND_DIR := backend
FRONTEND_DIR := frontend

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo '$(GREEN)Available targets:$(NC)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

# Infrastructure targets
init: ## Initialize Terraform
	@echo '$(GREEN)Initializing Terraform...$(NC)'
	cd $(TERRAFORM_DIR) && terraform init

workspace-dev: ## Select dev workspace
	@echo '$(GREEN)Selecting dev workspace...$(NC)'
	cd $(TERRAFORM_DIR) && terraform workspace select dev || terraform workspace new dev

workspace-sit: ## Select sit workspace
	@echo '$(GREEN)Selecting sit workspace...$(NC)'
	cd $(TERRAFORM_DIR) && terraform workspace select sit || terraform workspace new sit

workspace-uat: ## Select uat workspace
	@echo '$(GREEN)Selecting uat workspace...$(NC)'
	cd $(TERRAFORM_DIR) && terraform workspace select uat || terraform workspace new uat

workspace-prod: ## Select production workspace
	@echo '$(GREEN)Selecting production workspace...$(NC)'
	cd $(TERRAFORM_DIR) && terraform workspace select production || terraform workspace new production

plan-dev: workspace-dev ## Plan dev infrastructure
	@echo '$(GREEN)Planning dev infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform plan -var-file="environments/dev.tfvars"

plan-sit: workspace-sit ## Plan sit infrastructure
	@echo '$(GREEN)Planning sit infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform plan -var-file="environments/sit.tfvars"

plan-uat: workspace-uat ## Plan uat infrastructure
	@echo '$(GREEN)Planning uat infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform plan -var-file="environments/uat.tfvars"

plan-prod: workspace-prod ## Plan production infrastructure
	@echo '$(GREEN)Planning production infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform plan -var-file="environments/production.tfvars"

apply-dev: workspace-dev ## Apply dev infrastructure
	@echo '$(GREEN)Applying dev infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform apply -var-file="environments/dev.tfvars"

apply-sit: workspace-sit ## Apply sit infrastructure
	@echo '$(GREEN)Applying sit infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform apply -var-file="environments/sit.tfvars"

apply-uat: workspace-uat ## Apply uat infrastructure
	@echo '$(GREEN)Applying uat infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform apply -var-file="environments/uat.tfvars"

apply-prod: workspace-prod ## Apply production infrastructure
	@echo '$(GREEN)Applying production infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform apply -var-file="environments/production.tfvars"

destroy-dev: workspace-dev ## Destroy dev infrastructure
	@echo '$(YELLOW)Destroying dev infrastructure...$(NC)'
	cd $(TERRAFORM_DIR) && terraform destroy -var-file="environments/dev.tfvars"

# Kubernetes targets
install-gateway: ## Install Envoy Gateway v1.7.0 (prerequisite — run once per cluster)
	@echo '$(GREEN)Installing Envoy Gateway v1.7.0...$(NC)'
	bash infra/helm/install-envoy-gateway.sh

helm-install-dev: ## Install Helm chart (dev)
	@echo '$(GREEN)Installing Helm chart for dev...$(NC)'
	helm install ai-app $(HELM_DIR) -f $(HELM_DIR)/values-dev.yaml --namespace dev --create-namespace

helm-install-sit: ## Install Helm chart (sit)
	@echo '$(GREEN)Installing Helm chart for sit...$(NC)'
	helm install ai-app $(HELM_DIR) -f $(HELM_DIR)/values-sit.yaml --namespace sit --create-namespace

helm-install-uat: ## Install Helm chart (uat)
	@echo '$(GREEN)Installing Helm chart for uat...$(NC)'
	helm install ai-app $(HELM_DIR) -f $(HELM_DIR)/values-uat.yaml --namespace uat --create-namespace

helm-install-prod: ## Install Helm chart (production)
	@echo '$(GREEN)Installing Helm chart for production...$(NC)'
	helm install ai-app $(HELM_DIR) -f $(HELM_DIR)/values-production.yaml --namespace production --create-namespace

helm-upgrade-dev: ## Upgrade Helm chart (dev)
	@echo '$(GREEN)Upgrading Helm chart for dev...$(NC)'
	helm upgrade ai-app $(HELM_DIR) -f $(HELM_DIR)/values-dev.yaml --namespace dev

helm-uninstall-dev: ## Uninstall Helm chart (dev)
	@echo '$(YELLOW)Uninstalling Helm chart from dev...$(NC)'
	helm uninstall ai-app --namespace dev

# Local development targets
dev: ## Start local development environment
	@echo '$(GREEN)Starting local development environment...$(NC)'
	docker-compose up -d
	@echo '$(GREEN)Backend: http://localhost:8000$(NC)'
	@echo '$(GREEN)Frontend: http://localhost:3000$(NC)'
	@echo '$(GREEN)API Docs: http://localhost:8000/docs$(NC)'

up: dev ## Alias for dev

down: ## Stop local development environment
	@echo '$(YELLOW)Stopping local development environment...$(NC)'
	docker-compose down

logs: ## Show logs from all services
	docker-compose logs -f

logs-backend: ## Show backend logs
	docker-compose logs -f backend

logs-frontend: ## Show frontend logs
	docker-compose logs -f frontend

# Backend targets
backend-install: ## Install backend dependencies
	@echo '$(GREEN)Installing backend dependencies...$(NC)'
	cd $(BACKEND_DIR) && pip install -r requirements.txt -r requirements-dev.txt

backend-test: ## Run backend tests
	@echo '$(GREEN)Running backend tests...$(NC)'
	cd $(BACKEND_DIR) && pytest tests/ -v

backend-lint: ## Lint backend code
	@echo '$(GREEN)Linting backend code...$(NC)'
	cd $(BACKEND_DIR) && ruff check app/ tests/
	cd $(BACKEND_DIR) && mypy app/

backend-format: ## Format backend code
	@echo '$(GREEN)Formatting backend code...$(NC)'
	cd $(BACKEND_DIR) && ruff format app/ tests/

backend-run: ## Run backend locally
	@echo '$(GREEN)Running backend...$(NC)'
	cd $(BACKEND_DIR) && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Frontend targets
frontend-install: ## Install frontend dependencies
	@echo '$(GREEN)Installing frontend dependencies...$(NC)'
	cd $(FRONTEND_DIR) && npm install

frontend-test: ## Run frontend tests
	@echo '$(GREEN)Running frontend tests...$(NC)'
	cd $(FRONTEND_DIR) && npm test

frontend-lint: ## Lint frontend code
	@echo '$(GREEN)Linting frontend code...$(NC)'
	cd $(FRONTEND_DIR) && npm run lint

frontend-build: ## Build frontend
	@echo '$(GREEN)Building frontend...$(NC)'
	cd $(FRONTEND_DIR) && npm run build

frontend-run: ## Run frontend locally
	@echo '$(GREEN)Running frontend...$(NC)'
	cd $(FRONTEND_DIR) && npm run dev

# Docker targets
docker-build-backend: ## Build backend Docker image
	@echo '$(GREEN)Building backend Docker image...$(NC)'
	docker build -t ai-app-backend:latest $(BACKEND_DIR)

docker-build-frontend: ## Build frontend Docker image
	@echo '$(GREEN)Building frontend Docker image...$(NC)'
	docker build -t ai-app-frontend:latest $(FRONTEND_DIR)

docker-build: docker-build-backend docker-build-frontend ## Build all Docker images

# Utility targets
clean: ## Clean temporary files
	@echo '$(YELLOW)Cleaning temporary files...$(NC)'
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true
	@echo '$(GREEN)Clean complete!$(NC)'

test: backend-test frontend-test ## Run all tests

lint: backend-lint frontend-lint ## Run all linters

format: backend-format ## Format all code

install: backend-install frontend-install ## Install all dependencies

#!/bin/bash

# Test Script for Azure AI Chat Application
# Usage: ./scripts/test.sh <component> [environment]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test backend
test_backend() {
    log_info "Testing backend..."
    cd "$PROJECT_ROOT/backend"
    
    # Run pytest
    pytest -v --cov=app --cov-report=term-missing
    
    # Type checking
    mypy app/
    
    # Linting
    flake8 app/
    
    log_info "Backend tests passed ✓"
}

# Test frontend
test_frontend() {
    log_info "Testing frontend..."
    cd "$PROJECT_ROOT/frontend"
    
    # Run tests
    npm test -- --coverage
    
    # Type checking
    npm run type-check
    
    # Linting
    npm run lint
    
    log_info "Frontend tests passed ✓"
}

# Test Helm chart
test_helm() {
    log_info "Testing Helm chart..."
    cd "$PROJECT_ROOT/infra/helm/ai-app"
    
    # Lint chart
    helm lint . --values values.yaml
    
    # Template validation
    helm template ai-app . \
        --values values.yaml \
        --values environments/dev-values.yaml | \
        kubectl apply --dry-run=client -f -
    
    log_info "Helm chart tests passed ✓"
}

# Test Terraform
test_terraform() {
    local env=${1:-dev}
    log_info "Testing Terraform for environment: $env"
    cd "$PROJECT_ROOT/infra/terraform/environments/$env"
    
    # Format check
    terraform fmt -check -recursive
    
    # Validate
    terraform init -backend=false
    terraform validate
    
    # Plan
    terraform plan -var-file="${env}.tfvars"
    
    log_info "Terraform tests passed ✓"
}

# Integration tests
test_integration() {
    local env=${1:-dev}
    log_info "Running integration tests for environment: $env"
    
    # Load environment
    if [ -f "$PROJECT_ROOT/.env.$env" ]; then
        source "$PROJECT_ROOT/.env.$env"
    fi
    
    # Get Gateway IP
    GATEWAY_IP=$(kubectl get gateway ai-app-gateway -n ai-app-$env \
        -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
    
    if [ -z "$GATEWAY_IP" ]; then
        log_error "Gateway not found. Application not deployed?"
        exit 1
    fi
    
    # Test frontend
    log_info "Testing frontend endpoint..."
    curl -f -H "Host: ai-app-$env.example.com" http://$GATEWAY_IP/ || {
        log_error "Frontend test failed"
        exit 1
    }
    
    # Test backend health
    log_info "Testing backend health..."
    curl -f -H "Host: ai-app-$env.example.com" \
        http://$GATEWAY_IP/api/v1/health/ || {
        log_error "Backend health check failed"
        exit 1
    }
    
    log_info "Integration tests passed ✓"
}

# Load tests
test_load() {
    local env=${1:-dev}
    log_info "Running load tests for environment: $env"
    
    # Check if k6 is installed
    if ! command -v k6 &> /dev/null; then
        log_warn "k6 not installed. Skipping load tests."
        return
    fi
    
    # Get Gateway IP
    GATEWAY_IP=$(kubectl get gateway ai-app-gateway -n ai-app-$env \
        -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
    
    if [ -z "$GATEWAY_IP" ]; then
        log_error "Gateway not found"
        exit 1
    fi
    
    # Create k6 script
    cat > /tmp/load-test.js <<EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('http://${GATEWAY_IP}/api/v1/health/', {
    headers: { 'Host': 'ai-app-${env}.example.com' },
  });
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
EOF
    
    # Run k6
    k6 run /tmp/load-test.js
    
    log_info "Load tests passed ✓"
}

# Main
main() {
    local component=$1
    local env=${2:-dev}
    
    case $component in
        backend)
            test_backend
            ;;
        frontend)
            test_frontend
            ;;
        helm)
            test_helm
            ;;
        terraform)
            test_terraform $env
            ;;
        integration)
            test_integration $env
            ;;
        load)
            test_load $env
            ;;
        all)
            test_backend
            test_frontend
            test_helm
            test_terraform $env
            ;;
        *)
            log_error "Usage: $0 <component> [environment]"
            log_error "Components: backend, frontend, helm, terraform, integration, load, all"
            exit 1
            ;;
    esac
    
    log_info "All tests passed! 🎉"
}

main "$@"

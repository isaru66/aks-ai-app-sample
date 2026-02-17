#!/bin/bash

# Environment Setup Script
# Usage: ./scripts/setup-env.sh <environment>

set -e

GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

setup_dev_environment() {
    log_info "Setting up development environment..."
    
    # Install backend dependencies
    log_info "Installing backend dependencies..."
    cd "$PROJECT_ROOT/backend"
    python -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    pip install -r requirements-dev.txt
    
    # Install frontend dependencies
    log_info "Installing frontend dependencies..."
    cd "$PROJECT_ROOT/frontend"
    npm install
    
    # Create .env files
    log_info "Creating environment files..."
    
    # Backend .env
    cat > "$PROJECT_ROOT/backend/.env" <<EOF
ENVIRONMENT=development
LOG_LEVEL=DEBUG
AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-52-deployment
AZURE_OPENAI_MODEL=gpt-5.2
AZURE_COSMOSDB_ENDPOINT=https://your-cosmos.documents.azure.com:443/
AZURE_COSMOSDB_KEY=your-cosmos-key
AZURE_COSMOSDB_DATABASE=chatdb
AZURE_SEARCH_ENDPOINT=https://your-search.search.windows.net
AZURE_SEARCH_API_KEY=your-search-key
ENABLE_STREAMING=true
ENABLE_THINKING_PROCESS=true
EOF
    
    # Frontend .env.local
    cat > "$PROJECT_ROOT/frontend/.env.local" <<EOF
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
NODE_ENV=development
EOF
    
    # Setup pre-commit hooks
    log_info "Setting up pre-commit hooks..."
    cat > "$PROJECT_ROOT/.git/hooks/pre-commit" <<'EOF'
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Backend
cd backend
source venv/bin/activate
flake8 app/
mypy app/

# Frontend
cd ../frontend
npm run lint

echo "Pre-commit checks passed ✓"
EOF
    
    chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"
    
    log_info "Development environment setup complete ✓"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Update .env files with your Azure credentials"
    log_info "  2. Start backend: cd backend && source venv/bin/activate && uvicorn app.main:app --reload"
    log_info "  3. Start frontend: cd frontend && npm run dev"
}

setup_ci_environment() {
    log_info "Setting up CI environment..."
    
    # Install dependencies without dev packages
    cd "$PROJECT_ROOT/backend"
    pip install -r requirements.txt
    
    cd "$PROJECT_ROOT/frontend"
    npm ci --production=false
    
    log_info "CI environment setup complete ✓"
}

main() {
    local env=$1
    
    if [ -z "$env" ]; then
        log_info "Usage: $0 <dev|ci>"
        exit 1
    fi
    
    case $env in
        dev)
            setup_dev_environment
            ;;
        ci)
            setup_ci_environment
            ;;
        *)
            log_info "Invalid environment: $env"
            exit 1
            ;;
    esac
}

main "$@"

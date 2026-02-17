# Helm Chart Testing Guide

## Prerequisites

```bash
# Install Helm
brew install helm  # macOS
choco install kubernetes-helm  # Windows

# Install Helm plugins
helm plugin install https://github.com/helm-unittest/helm-unittest
helm plugin install https://github.com/databus23/helm-diff
```

## Linting

### Lint the chart

```bash
cd infra/helm/ai-app
helm lint .
```

### Lint with environment values

```bash
helm lint . --values values.yaml --values environments/dev-values.yaml
helm lint . --values values.yaml --values environments/prod-values.yaml
```

## Template Rendering

### Render templates

```bash
helm template ai-app . \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --output-dir ./rendered
```

### Render specific template

```bash
helm template ai-app . \
  --values values.yaml \
  --show-only templates/backend-deployment.yaml
```

### Render with secrets

```bash
helm template ai-app . \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --set backend.secrets.azureOpenAI.apiKey=test-key \
  --set backend.secrets.cosmosDB.key=test-key \
  --set backend.secrets.search.apiKey=test-key
```

## Dry Run

### Dry run install

```bash
helm install ai-app . \
  --namespace ai-app-dev \
  --create-namespace \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --set backend.secrets.azureOpenAI.apiKey=test-key \
  --set backend.secrets.cosmosDB.key=test-key \
  --set backend.secrets.search.apiKey=test-key \
  --dry-run
```

### Dry run upgrade

```bash
helm upgrade ai-app . \
  --namespace ai-app-dev \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --dry-run
```

## Validation

### Validate against Kubernetes API

```bash
helm install ai-app . \
  --namespace ai-app-dev \
  --values values.yaml \
  --dry-run --validate
```

### Check rendered manifests with kubectl

```bash
helm template ai-app . \
  --values values.yaml \
  --values environments/dev-values.yaml | kubectl apply --dry-run=client -f -
```

## Diff

### Compare changes

```bash
# Install diff plugin first
helm plugin install https://github.com/databus23/helm-diff

# Show diff
helm diff upgrade ai-app . \
  --namespace ai-app-dev \
  --values values.yaml \
  --values environments/dev-values.yaml
```

## Unit Testing

### Run unit tests

```bash
helm unittest .
```

### Run specific test

```bash
helm unittest . -f tests/backend-deployment_test.yaml
```

## Integration Testing

### 1. Create test namespace

```bash
kubectl create namespace ai-app-test
```

### 2. Install chart

```bash
helm install ai-app-test . \
  --namespace ai-app-test \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --set backend.secrets.azureOpenAI.apiKey=test-key \
  --set backend.secrets.cosmosDB.key=test-key \
  --set backend.secrets.search.apiKey=test-key \
  --wait --timeout 5m
```

### 3. Test deployments

```bash
# Check all resources
kubectl get all -n ai-app-test

# Check pods
kubectl get pods -n ai-app-test
kubectl describe pod -n ai-app-test

# Check services
kubectl get svc -n ai-app-test

# Check Gateway
kubectl get gateway -n ai-app-test
kubectl describe gateway -n ai-app-test

# Check HTTPRoutes
kubectl get httproute -n ai-app-test
```

### 4. Test health endpoints

```bash
# Port forward backend
kubectl port-forward svc/ai-app-test-backend 8000:8000 -n ai-app-test &

# Test backend health
curl http://localhost:8000/api/v1/health/

# Port forward frontend
kubectl port-forward svc/ai-app-test-frontend 3000:3000 -n ai-app-test &

# Test frontend health
curl http://localhost:3000/api/health
```

### 5. Test autoscaling

```bash
# Check HPA
kubectl get hpa -n ai-app-test

# Generate load
kubectl run -it --rm load-generator \
  --image=busybox \
  --namespace=ai-app-test \
  -- /bin/sh -c "while true; do wget -q -O- http://ai-app-test-backend:8000/api/v1/health/; done"

# Watch scaling
kubectl get hpa -n ai-app-test --watch
```

### 6. Cleanup

```bash
helm uninstall ai-app-test --namespace ai-app-test
kubectl delete namespace ai-app-test
```

## Smoke Tests

### After deployment

```bash
# Test Gateway endpoint
GATEWAY_IP=$(kubectl get gateway ai-app-gateway -n ai-app-dev -o jsonpath='{.status.addresses[0].value}')

# Test frontend
curl -H "Host: ai-app-dev.example.com" http://$GATEWAY_IP/

# Test backend API
curl -H "Host: ai-app-dev.example.com" http://$GATEWAY_IP/api/v1/health/

# Test SSE streaming (requires auth token)
curl -N -H "Host: ai-app-dev.example.com" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"stream":true}' \
  http://$GATEWAY_IP/api/v1/chat/completions
```

## Performance Testing

### Load test with k6

```bash
# Install k6
brew install k6  # macOS

# Create test script
cat > load-test.js <<'EOF'
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '3m', target: 50 },
    { duration: '1m', target: 0 },
  ],
};

export default function () {
  const res = http.get('http://ai-app-dev.example.com/api/v1/health/');
  check(res, { 'status is 200': (r) => r.status === 200 });
}
EOF

# Run load test
k6 run load-test.js
```

## Debugging

### Check rendered templates

```bash
# Show all rendered templates
helm template ai-app . --values values.yaml --debug

# Check specific template with debug
helm template ai-app . \
  --values values.yaml \
  --show-only templates/gateway.yaml \
  --debug
```

### Verify values

```bash
# Show computed values
helm get values ai-app -n ai-app-dev

# Show all values (including defaults)
helm get values ai-app -n ai-app-dev --all
```

### Check release history

```bash
helm history ai-app -n ai-app-dev
```

### Rollback if needed

```bash
helm rollback ai-app 1 -n ai-app-dev
```

---

**For CI/CD integration, see**: `../../docs/cicd-guide.md`

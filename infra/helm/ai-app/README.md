# Helm Chart for Azure AI Chat Application

This Helm chart deploys the complete AI Chat Application with:
- ✅ Backend (FastAPI + GPT-5.2)
- ✅ Frontend (Next.js 16)
- ✅ Envoy Gateway API
- ✅ Autoscaling (HPA)
- ✅ Network Policies
- ✅ Monitoring (ServiceMonitor)
- ✅ Azure Workload Identity

## Prerequisites

- Kubernetes 1.28+
- Helm 3.10+
- Envoy Gateway installed
- Azure Container Registry access
- Azure OpenAI, Cosmos DB, AI Search provisioned

## Installation

### 1. Install Envoy Gateway (if not already installed)

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.0.0 \
  -n envoy-gateway-system \
  --create-namespace
```

### 2. Create namespace

```bash
kubectl create namespace ai-app-dev
```

### 3. Create ACR secret

```bash
kubectl create secret docker-registry acr-secret \
  --docker-server=acrdev001.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n ai-app-dev
```

### 4. Install the chart

#### Development Environment

```bash
helm install ai-app . \
  --namespace ai-app-dev \
  --values values.yaml \
  --values environments/dev-values.yaml \
  --set backend.secrets.azureOpenAI.apiKey=<your-api-key> \
  --set backend.secrets.cosmosDB.key=<your-cosmos-key> \
  --set backend.secrets.search.apiKey=<your-search-key>
```

#### Production Environment

```bash
helm install ai-app . \
  --namespace ai-app-prod \
  --values values.yaml \
  --values environments/prod-values.yaml \
  --set backend.secrets.azureOpenAI.apiKey=<your-api-key> \
  --set backend.secrets.cosmosDB.key=<your-cosmos-key> \
  --set backend.secrets.search.apiKey=<your-search-key>
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.environment` | Environment name | `dev` |
| `backend.replicaCount` | Number of backend replicas | `2` |
| `backend.autoscaling.enabled` | Enable HPA for backend | `true` |
| `backend.autoscaling.maxReplicas` | Max backend replicas | `10` |
| `frontend.replicaCount` | Number of frontend replicas | `3` |
| `frontend.autoscaling.maxReplicas` | Max frontend replicas | `20` |
| `gateway.enabled` | Enable Envoy Gateway | `true` |
| `gateway.tls.enabled` | Enable TLS | `true` |

### Environment-specific values

Create environment-specific value files:

- `environments/dev-values.yaml`
- `environments/sit-values.yaml`
- `environments/uat-values.yaml`
- `environments/prod-values.yaml`

## Envoy Gateway Configuration

The chart creates:

1. **Gateway**: Entry point with HTTP/HTTPS listeners
2. **HTTPRoutes**: Route rules for frontend and backend
3. **ClientTrafficPolicy**: TLS configuration
4. **BackendTrafficPolicy**: Load balancing, timeouts, health checks
5. **SecurityPolicy**: CORS, JWT, authorization

### SSE Streaming Support

The backend HTTPRoute includes special configuration for SSE streaming:

```yaml
timeouts:
  request: 300s  # 5 minutes for long-running streams
  backendRequest: 300s
```

## Upgrade

```bash
helm upgrade ai-app . \
  --namespace ai-app-dev \
  --values values.yaml \
  --values environments/dev-values.yaml
```

## Uninstall

```bash
helm uninstall ai-app --namespace ai-app-dev
```

## Testing

### Test Gateway

```bash
# Get Gateway address
kubectl get gateway -n ai-app-dev

# Test frontend
curl http://ai-app-dev.example.com/

# Test backend health
curl http://ai-app-dev.example.com/api/v1/health/

# Test SSE streaming (with auth token)
curl -N -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"stream":true}' \
  http://ai-app-dev.example.com/api/v1/chat/completions
```

## Monitoring

### View metrics

```bash
# Backend metrics
kubectl port-forward svc/ai-app-backend 8000:8000 -n ai-app-dev
curl http://localhost:8000/metrics

# Frontend metrics  
kubectl port-forward svc/ai-app-frontend 3000:3000 -n ai-app-dev
curl http://localhost:3000/metrics
```

### Check HPA status

```bash
kubectl get hpa -n ai-app-dev
kubectl describe hpa ai-app-backend -n ai-app-dev
```

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n ai-app-dev
kubectl logs -f <pod-name> -n ai-app-dev
```

### Check Gateway status

```bash
kubectl get gateway -n ai-app-dev
kubectl describe gateway ai-app-gateway -n ai-app-dev
```

### Check HTTPRoutes

```bash
kubectl get httproute -n ai-app-dev
kubectl describe httproute ai-app-frontend -n ai-app-dev
```

### Check policies

```bash
kubectl get clienttrafficpolicy -n ai-app-dev
kubectl get backendtrafficpolicy -n ai-app-dev
kubectl get securitypolicy -n ai-app-dev
```

## Architecture

```
Internet
    ↓
Envoy Gateway (LoadBalancer)
    ↓
Gateway + HTTPRoutes
    ├── Frontend (/) → Frontend Service → Frontend Pods (3-20)
    └── Backend (/api) → Backend Service → Backend Pods (2-10)
         ↓
    Azure Services (OpenAI, Cosmos DB, AI Search)
```

## Features

### Autoscaling

- Backend: 2-10 pods based on CPU/Memory
- Frontend: 3-20 pods based on CPU/Memory
- Scale-up: Aggressive (100% every 30s)
- Scale-down: Conservative (50% every 60s with 5min stabilization)

### Security

- Pod Security Standards (restricted)
- Network Policies (ingress/egress)
- Non-root containers
- Read-only root filesystem
- Drop all capabilities

### High Availability

- Pod Disruption Budgets
- Pod Anti-Affinity
- Health checks (liveness/readiness)
- Multi-zone deployment support

### Observability

- Prometheus ServiceMonitors
- Application Insights integration
- Distributed tracing
- Custom metrics

---

**Maintained by Platform Team**

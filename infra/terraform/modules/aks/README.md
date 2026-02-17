# AKS Module

This module creates an Azure Kubernetes Service (AKS) cluster with **Envoy Gateway support**.

## Resources Created

- AKS Cluster with:
  - Azure CNI networking
  - Workload Identity & OIDC Issuer (for Envoy Gateway)
  - Container Insights
  - Key Vault Secrets Provider
  - Auto-scaling
- User-assigned Managed Identity
- System node pool
- User node pool (for applications)
- Role assignments (ACR pull, network contributor)

## Envoy Gateway Support

This AKS configuration is optimized for **Envoy Gateway API**:

✅ **OIDC Issuer Enabled** - Required for Gateway API authentication  
✅ **Workload Identity** - For secure pod-to-Azure resource communication  
✅ **Azure CNI** - Better networking for gateway traffic  
✅ **Network Policy** - Security policies for gateway pods  
✅ **Standard Load Balancer** - Required for gateway external traffic  

## Usage

```hcl
module "aks" {
  source = "./modules/aks"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  environment                = "dev"
  resource_prefix            = "aks-ai-app-dev"
  random_suffix              = random_string.suffix.result
  kubernetes_version         = "1.29"
  node_count                 = 2
  node_size                  = "Standard_D4s_v3"
  enable_autoscaling         = true
  min_node_count             = 2
  max_node_count             = 10
  vnet_subnet_id             = module.networking.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_private_cluster     = false
  acr_id                     = module.acr.acr_id
  tags                       = local.common_tags
}
```

## Node Pools

### System Node Pool
- **Purpose**: Kubernetes system components
- **Label**: `workload=system`
- **Auto-scaling**: Enabled

### User Node Pool
- **Purpose**: Application workloads (backend, frontend)
- **Label**: `workload=application`
- **Auto-scaling**: Enabled

## Post-Deployment Steps

After creating AKS, install Envoy Gateway:

```bash
# Get credentials
az aks get-credentials --resource-group <rg> --name <cluster-name>

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install Envoy Gateway
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.0.0 \
  -n envoy-gateway-system \
  --create-namespace
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| resource_prefix | Prefix for resource naming | string | n/a | yes |
| random_suffix | Random suffix | string | n/a | yes |
| kubernetes_version | Kubernetes version | string | "1.29" | no |
| node_count | Initial node count | number | 2 | no |
| node_size | VM size | string | "Standard_D4s_v3" | no |
| enable_autoscaling | Enable autoscaling | bool | true | no |
| min_node_count | Min nodes | number | 2 | no |
| max_node_count | Max nodes | number | 10 | no |
| vnet_subnet_id | VNet subnet ID | string | n/a | yes |
| log_analytics_workspace_id | Log Analytics workspace ID | string | n/a | yes |
| enable_private_cluster | Enable private cluster | bool | false | no |
| acr_id | ACR ID | string | n/a | yes |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | AKS cluster ID |
| cluster_name | AKS cluster name |
| oidc_issuer_url | OIDC issuer URL (for Gateway API) |
| identity_principal_id | Managed identity principal ID |

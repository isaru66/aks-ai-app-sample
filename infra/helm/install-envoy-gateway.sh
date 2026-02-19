#!/usr/bin/env bash
# =============================================================================
# Install Envoy Gateway as a prerequisite before deploying the ai-app Helm chart.
#
# Envoy Gateway v1.7.0 requires Gateway API CRDs v1.2.x.
# Run this once per cluster before running helm-install-<env>.
# =============================================================================

set -euo pipefail

ENVOY_GATEWAY_VERSION="v1.7.0"
GATEWAY_API_VERSION="v1.2.1"
NAMESPACE="envoy-gateway-system"

echo "==> Installing Gateway API CRDs (${GATEWAY_API_VERSION})..."
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

echo "==> Installing Envoy Gateway (${ENVOY_GATEWAY_VERSION})..."
helm install eg \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_GATEWAY_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace

echo "==> Waiting for Envoy Gateway to be ready..."
kubectl wait --timeout=5m -n "${NAMESPACE}" \
  deployment/envoy-gateway \
  --for=condition=Available

echo "==> Envoy Gateway ${ENVOY_GATEWAY_VERSION} installed successfully."

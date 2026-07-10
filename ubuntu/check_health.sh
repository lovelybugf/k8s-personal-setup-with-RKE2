#!/bin/bash
set -e

echo "=========================================="
echo "   KUBERNETES KUBECTL SETUP & HEALTH CHECK"
echo "=========================================="

# 1. Configure kubectl for current user if needed
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
  mkdir -p ~/.kube
  cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
  chmod 600 ~/.kube/config
  echo "✅ Configured ~/.kube/config successfully."
else
  echo "⚠️  RKE2 config not found at /etc/rancher/rke2/rke2.yaml."
  echo "   Make sure this script is run on the Master node."
fi

# Ensure /usr/local/bin and RKE2 bin are in PATH (in case it is not)
export PATH=$PATH:/usr/local/bin:/var/lib/rancher/rke2/bin

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ Error: kubectl command not found!"
  exit 1
fi

echo ""
echo "===== 1. CLUSTER CONNECTION INFO ====="
kubectl cluster-info || echo "❌ Failed to connect to API Server!"

echo ""
echo "===== 2. CLUSTER NODES STATUS ====="
kubectl get nodes -o wide

echo ""
echo "===== 3. UNHEALTHY PODS (IF ANY) ====="
# Check for pods that are not in Running or Succeeded state (ignores Completed installer jobs)
UNHEALTHY_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || true)
if [ -z "$UNHEALTHY_PODS" ]; then
  echo "✅ All active Pods are running or succeeded!"
else
  echo "⚠️  Some pods are not in Running or Succeeded status:"
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
fi

echo ""
echo "===== 4. CORE SERVICES (KUBE-SYSTEM) ====="
kubectl get deployments,daemonsets -n kube-system

echo "=========================================="
echo "   HEALTH CHECK COMPLETED"
echo "=========================================="

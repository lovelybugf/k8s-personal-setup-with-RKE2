#!/bin/bash
set -e

HOST_IP=$1
HOSTNAME="${HOST_IP}.sslip.io"

if [ -z "$HOST_IP" ]; then
  echo "Usage: ./install_rancher.sh <NODE_IP>"
  exit 1
fi

echo "===================================="
echo " INSTALL RANCHER ON RKE2 CLUSTER"
echo " HOSTNAME: $HOSTNAME"
echo "===================================="

# ===== 1. INSTALL HELM =====
echo "[1/8] Installing Helm..."
curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ===== 2. ADD REPO =====
echo "[2/8] Adding Rancher repo..."
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# ===== 3. CREATE NAMESPACE =====
echo "[3/8] Creating namespace..."
helm uninstall rancher -n cattle-system 2>/dev/null || true
kubectl delete namespace cattle-system --ignore-not-found || true
kubectl create namespace cattle-system 2>/dev/null || true

# ===== 4. INSTALL CERT-MANAGER =====
echo "[4/8] Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

echo "Waiting cert-manager..."
kubectl wait --for=condition=available deploy/cert-manager -n cert-manager --timeout=180s
kubectl wait --for=condition=available deploy/cert-manager-webhook -n cert-manager --timeout=180s
kubectl wait --for=condition=available deploy/cert-manager-cainjector -n cert-manager --timeout=180s

echo "Bypassing cert-manager webhook to prevent cross-node CNI network timeouts..."
kubectl delete validatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true

# ===== 5. FIX STORAGE -> /data =====
echo "[5/8] Configuring storage to /data..."

mkdir -p /data/local-path

echo "Installing/Configuring local-path-provisioner..."
curl -sL https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml | \
  sed 's/namespace: local-path-storage/namespace: kube-system/g' | \
  sed 's|/opt/local-path-provisioner|/data/local-path|g' | \
  kubectl apply -f -

# Set as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || true

kubectl rollout restart deployment local-path-provisioner -n kube-system

# ===== 6. INSTALL RANCHER =====
echo "[6/8] Installing Rancher..."

helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=$HOSTNAME \
  --set replicas=1 \
  --set bootstrapPassword=admin

# ===== 7. WAIT RANCHER READY =====
echo "[7/8] Waiting Rancher ready..."

kubectl rollout status deployment rancher -n cattle-system --timeout=300s

# ===== 8. SHOW INFO =====
echo "[8/8] DONE"

echo "===================================="
echo "RANCHER URL:"
echo "https://$HOSTNAME"
echo ""
echo "USER: admin"
echo "PASS: admin"
echo "===================================="

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
kubectl create namespace cattle-system 2>/dev/null || true

# ===== 4. INSTALL CERT-MANAGER =====
echo "[4/8] Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

echo "Waiting cert-manager..."
kubectl wait --for=condition=available deploy/cert-manager -n cert-manager --timeout=180s
kubectl wait --for=condition=available deploy/cert-manager-webhook -n cert-manager --timeout=180s
kubectl wait --for=condition=available deploy/cert-manager-cainjector -n cert-manager --timeout=180s

# ===== 5. FIX STORAGE -> /data =====
echo "[5/8] Configuring storage to /data..."

mkdir -p /data/local-path

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: kube-system
data:
  config.json: |-
    {
      "nodePathMap":[
      {
        "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
        "paths":["/data/local-path"]
      }
      ]
    }
EOF

kubectl rollout restart deployment local-path-provisioner -n kube-system

# ===== 6. INSTALL RANCHER =====
echo "[6/8] Installing Rancher..."

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=$HOSTNAME \
  --set replicas=1 \
  --set bootstrapPassword=admin \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-path \
  --set persistence.size=10Gi

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
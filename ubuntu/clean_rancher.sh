#!/bin/bash
# Script chuyên biệt để dọn dẹp các tàn dư Rancher cũ trong cụm K8s RKE2
set -e

echo "=================================================="
echo "      RANCHER CLEANUP UTILITY FOR RKE2"
echo "=================================================="

# 1. Khai báo biến KUBECONFIG
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
fi

# Ensure /usr/local/bin and RKE2 bin are in PATH
export PATH=$PATH:/usr/local/bin:/var/lib/rancher/rke2/bin

# 2. Gỡ cài đặt Helm Release của Rancher
echo "1. Gỡ cài đặt Helm release Rancher..."
helm uninstall rancher -n cattle-system 2>/dev/null || true

# 3. Xóa các Webhook cấu hình gây lỗi kẹt
echo "2. Xóa các Webhook cấu hình để tránh lỗi kẹt mạng CNI..."
kubectl delete validatingwebhookconfiguration rancher.cattle.io 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration rancher.cattle.io 2>/dev/null || true
kubectl delete validatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete validatingwebhookconfiguration rke2-ingress-nginx-admission 2>/dev/null || true

# 4. Xóa APIServices của Rancher (đây là lý do chính khiến Namespace bị kẹt Terminating)
echo "3. Dọn dẹp APIServices của Rancher..."
kubectl delete apiservice v1.management.cattle.io 2>/dev/null || true

# 5. Xóa các Namespace liên quan tới Rancher
echo "4. Xóa các Namespace của Rancher (cattle-system, fleet)..."
NAMESPACES=("cattle-system" "cattle-fleet-system" "cattle-fleet-local-system" "cattle-impersonation-system" "cattle-global-data")
for ns in "${NAMESPACES[@]}"; do
  echo "   Đang xóa namespace: $ns..."
  kubectl delete namespace $ns --timeout=15s 2>/dev/null || true
done

echo ""
echo "=================================================="
echo "   ĐÃ DỌN DẸP SẠCH SẼ TÀN DƯ RANCHER CŨ!"
echo "=================================================="

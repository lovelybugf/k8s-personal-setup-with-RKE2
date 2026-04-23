#!/bin/bash
set -e

echo "===================================="
echo "  FULL K8s / RKE2 / K3s DATA WIPE"
echo "===================================="

read -p "TYPE YES TO WIPE ALL DATA (/data included): " ok
[ "$ok" != "YES" ] && exit 1

echo "[1] Stop services..."
systemctl stop rke2-server 2>/dev/null || true
systemctl stop rke2-agent 2>/dev/null || true
systemctl stop k3s 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true

echo "[2] Kill processes..."
pkill -9 kubelet 2>/dev/null || true
pkill -9 containerd 2>/dev/null || true

sleep 3

echo "[3] Unmount kube/k3s mounts..."
mount | grep -E "kube|k3s|containerd" | awk '{print $3}' | while read m; do
    umount -lf "$m" 2>/dev/null || true
done

echo "[4] WIPE /data cluster storage..."
rm -rf /data/rancher
rm -rf /data/k3s
rm -rf /data/containerd
rm -rf /data/kubelet
rm -rf /data/etcd

echo "[5] WIPE system kube state..."
rm -rf /var/lib/kubelet
rm -rf /etc/cni/net.d
rm -rf /opt/cni/bin
rm -rf /run/k3s
rm -rf /run/containerd

echo "[6] WIPE RKE2 state..."
rm -rf /etc/rancher/rke2
rm -rf /var/lib/rancher/rke2

echo "[7] Restart container runtime..."
systemctl restart containerd 2>/dev/null || true

echo "===================================="
echo " FULL WIPE DONE"
echo " CHECK df -h NOW"
echo "===================================="

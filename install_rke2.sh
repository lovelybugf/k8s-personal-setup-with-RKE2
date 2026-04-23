#!/bin/bash
set -e

NODE_IP=$1
ROLE=$2          # init | join
SERVER_IP=$3
TOKEN=$4

DATA_DIR="/data/rke2"
KUBECONFIG_PATH="/etc/rancher/rke2/rke2.yaml"

if [ -z "$NODE_IP" ] || [ -z "$ROLE" ]; then
  echo "Usage:"
  echo " INIT : ./install_rke2.sh <NODE_IP> init"
  echo " JOIN : ./install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>"
  exit 1
fi

echo "===== SET HOSTNAME ====="
hostnamectl set-hostname node-${NODE_IP//./-}

echo "===== CREATE DATA DIR ====="
mkdir -p $DATA_DIR
mkdir -p /etc/rancher/rke2

echo "===== WRITE CONFIG ====="

if [ "$ROLE" == "init" ]; then

cat <<EOF > /etc/rancher/rke2/config.yaml
data-dir: $DATA_DIR
write-kubeconfig-mode: "0644"
tls-san:
  - $NODE_IP
EOF

INSTALL_TYPE="server"

else

cat <<EOF > /etc/rancher/rke2/config.yaml
server: https://$SERVER_IP:9345
token: $TOKEN
data-dir: $DATA_DIR
EOF

INSTALL_TYPE="agent"

fi

echo "===== INSTALL RKE2 ====="
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=$INSTALL_TYPE sh -

echo "===== ENABLE SERVICE ====="

if [ "$ROLE" == "init" ]; then
  systemctl enable rke2-server
  systemctl restart rke2-server
else
  systemctl enable rke2-agent
  systemctl restart rke2-agent
fi

echo "===== WAIT START ====="
sleep 60

echo "===== VERIFY ====="
if [ "$ROLE" == "init" ]; then
  export KUBECONFIG=$KUBECONFIG_PATH
  kubectl get nodes || true
  cat $DATA_DIR/server/node-token
else
  journalctl -u rke2-agent --no-pager | tail -n 30
fi

echo "===== DONE ====="

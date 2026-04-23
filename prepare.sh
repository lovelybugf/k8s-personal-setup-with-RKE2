#!/bin/bash

# Update
apt update -y
apt install -y curl wget vim net-tools

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

#!/bin/bash
set -e

# Update and install utilities
if command -v dnf >/dev/null 2>&1; then
  dnf install -y curl wget vim net-tools chrony tar iptables
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl wget vim net-tools chrony tar iptables
else
  echo "ERROR: Neither dnf nor yum package managers found"
  exit 1
fi

# Install EPEL 10 and ncdu (for disk usage management)
echo "===== INSTALL EPEL 10 & NCDU ====="
if command -v dnf >/dev/null 2>&1; then
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
  dnf install -y ncdu
elif command -v yum >/dev/null 2>&1; then
  yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
  yum install -y ncdu
fi


# Enable and start time sync (chronyd is standard on RHEL/CentOS/Rocky)
systemctl enable --now chronyd

# Disable firewall (firewalld) permanently
if systemctl is-active --quiet firewalld 2>/dev/null || systemctl is-enabled --quiet firewalld 2>/dev/null; then
  echo "Disabling firewalld..."
  systemctl disable --now firewalld || true
fi

# SELinux Configuration (Disable SELinux completely)
if command -v setenforce >/dev/null 2>&1; then
  echo "Disabling SELinux..."
  setenforce 0 || true
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config || true
fi

# NetworkManager configuration to ignore K8s interfaces (Recommended for RHEL-based systems)
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
  echo "Configuring NetworkManager to ignore K8s interfaces..."
  mkdir -p /etc/NetworkManager/conf.d
  cat <<EOF > /etc/NetworkManager/conf.d/rke2-canal.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*;interface-name:veth*
EOF
  systemctl reload NetworkManager || true
fi

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
echo "Configuring Kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl
echo "Configuring Sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

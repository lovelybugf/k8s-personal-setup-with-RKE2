# k8s-personal-setup-with-RKE2

Opinionated bootstrap scripts to stand up a small **RKE2** Kubernetes cluster and (optionally) install **Rancher** on top.

- **Target**: personal / homelab clusters (quick setup, simple defaults)
- **OS**: Debian/Ubuntu-like Linux (uses `apt`)
- **Scope**: node preparation, RKE2 server/agent install, Rancher install, and a “wipe node” helper

---

## English

### Features

- **Host preparation**: installs common tools, disables swap, configures kernel modules + sysctl for Kubernetes
- **RKE2 install**:
  - **Init** node (server) with SAN set to your node IP
  - **Join** nodes (agent) using server IP + cluster token
- **Rancher install** on the cluster via Helm, using `sslip.io` hostname
- **Full wipe helper** to remove RKE2/K3s/containerd/kube state (dangerous)

### Repository layout

- `prepare.sh`: basic OS/node prep for Kubernetes
- `install_rke2.sh`: install RKE2 as `server` (init) or `agent` (join)
- `get_token.sh`: prints the RKE2 node token from `/data/rke2/server/node-token`
- `install_rancher.sh`: installs cert-manager + Rancher (Helm) and configures local-path storage under `/data`
- `rke2-clean-node.sh`: **DANGEROUS** full wipe of Kubernetes-related state (including `/data`)

### Prerequisites

- **Linux** node(s) with `apt` (Ubuntu/Debian)
- **Root / sudo** access
- **Network**:
  - Nodes can reach each other over the LAN
  - Inbound to the RKE2 server: **9345/tcp** (RKE2 supervisor) and **6443/tcp** (Kubernetes API)
  - If installing Rancher: **443/tcp** to the node where Rancher is exposed

### Quickstart (1 server + 1+ agents)

#### 0) Prepare every node

Run on each node:

```bash
sudo bash prepare.sh
```

Reboot if your environment requires it (kernel/module changes usually take effect immediately, but rebooting is often the least surprising option).

#### 1) Init the first server node

On the node you want as the first control-plane/server:

```bash
sudo bash install_rke2.sh <NODE_IP> init
```

Notes:
- This writes config to `/etc/rancher/rke2/config.yaml`
- Cluster data dir is `/data/rke2`
- Kubeconfig will be at `/etc/rancher/rke2/rke2.yaml` (mode `0644`)

#### 2) Get the join token

On the server node:

```bash
sudo bash get_token.sh
```

Save the printed token.

#### 3) Join agent nodes

On each additional node:

```bash
sudo bash install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
```

The script will print recent `rke2-agent` logs at the end to help you spot issues.

#### 4) Verify from the server node

On the server node:

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide
```

### Install Rancher (optional)

Run this on the server node (or any node with working `kubectl` context to the cluster):

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
sudo bash install_rancher.sh <NODE_IP>
```

What it does:
- Installs Helm (via upstream script)
- Installs cert-manager (currently pinned to `v1.14.5`)
- Reconfigures `local-path-provisioner` to store PV data under `/data/local-path`
- Installs Rancher with:
  - **hostname**: `<NODE_IP>.sslip.io`
  - **bootstrapPassword**: `admin`
  - **replicas**: `1`
  - **persistence**: enabled (`10Gi`, `local-path`)

After it finishes, open:
- `https://<NODE_IP>.sslip.io`

Credentials:
- user: `admin`
- pass: `admin`

### Troubleshooting

- **RKE2 server not ready**:
  - `sudo systemctl status rke2-server --no-pager`
  - `sudo journalctl -u rke2-server -n 200 --no-pager`
- **Agent can’t join**:
  - Verify **9345/tcp** from agent → server is reachable
  - Verify the token is correct and unmodified
  - `sudo journalctl -u rke2-agent -n 200 --no-pager`
- **kubectl not found**:
  - RKE2 installs `kubectl` at `/var/lib/rancher/rke2/bin/kubectl`
  - Either add it to `PATH`, or call it directly
- **Rancher rollout times out**:
  - Check cert-manager pods: `kubectl -n cert-manager get pods`
  - Check Rancher pods: `kubectl -n cattle-system get pods`
  - Check events: `kubectl -n cattle-system get events --sort-by=.lastTimestamp | tail -n 50`

### Uninstall / clean the node (DANGEROUS)

`rke2-clean-node.sh` will attempt to stop services, unmount Kubernetes/containerd mounts, and **delete data from `/data` and system paths**.

Before wiping a node, **remove it from the cluster** to avoid leaving the cluster in a broken / inconsistent state.

On a machine with `kubectl` access to the cluster (typically the server node):

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# 1) Stop scheduling new pods
kubectl cordon <NODE_NAME>

# 2) Evict workloads safely (adjust flags for your environment)
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data

# 3) Remove the node object from the cluster
kubectl delete node <NODE_NAME>
```

Notes:
- If the node is an **RKE2 server/control-plane**, do not wipe it unless you understand quorum/etcd implications.
- Draining may fail if you have strict PodDisruptionBudgets; resolve those before proceeding.

Only run it if you fully understand the impact:

```bash
sudo bash rke2-clean-node.sh
```

It requires you to type `YES` before proceeding.

### Security notes

- Rancher is installed with **bootstrap password `admin`**. Change it immediately.
- Kubeconfig is written with mode `0644` on the init node. Restrict it if your environment requires stricter access.

---

## Tiếng Việt

### Giới thiệu

Repo này chứa các script “bootstrap” theo hướng đơn giản/nhanh để dựng một cụm **Kubernetes RKE2** (1 server + nhiều agent) và (tuỳ chọn) cài **Rancher** lên trên.

- **Mục tiêu**: homelab / môi trường cá nhân
- **Hệ điều hành**: Linux dạng Debian/Ubuntu (có `apt`)
- **Phạm vi**: chuẩn bị node, cài RKE2 server/agent, cài Rancher, và script xoá sạch dữ liệu node

### Cấu trúc repo

- `prepare.sh`: cài gói cần thiết, tắt swap, bật kernel modules + sysctl cho Kubernetes
- `install_rke2.sh`: cài RKE2 theo vai trò `init` (server) hoặc `join` (agent)
- `get_token.sh`: in token join từ `/data/rke2/server/node-token`
- `install_rancher.sh`: cài cert-manager + Rancher qua Helm, cấu hình local-path lưu ở `/data`
- `rke2-clean-node.sh`: **NGUY HIỂM** xoá sạch state K8s/RKE2/K3s/containerd (bao gồm `/data`)

### Yêu cầu trước khi chạy

- **Linux** (Ubuntu/Debian) có `apt`
- **Quyền root / sudo**
- **Mạng/Port**:
  - Các node truy cập được lẫn nhau
  - Mở vào node server: **9345/tcp** và **6443/tcp**
  - Nếu cài Rancher: truy cập **443/tcp** tới node expose Rancher

### Cài nhanh (1 server + 1+ agent)

#### 0) Chuẩn bị trên tất cả các node

Chạy trên từng node:

```bash
sudo bash prepare.sh
```

Nếu bạn muốn “chắc ăn”, có thể reboot sau khi chạy (thường không bắt buộc).

#### 1) Init node server đầu tiên

Trên node bạn chọn làm server/control-plane:

```bash
sudo bash install_rke2.sh <NODE_IP> init
```

Thông tin:
- File cấu hình: `/etc/rancher/rke2/config.yaml`
- Data dir: `/data/rke2`
- Kubeconfig: `/etc/rancher/rke2/rke2.yaml` (mode `0644`)

#### 2) Lấy token để join

Trên node server:

```bash
sudo bash get_token.sh
```

Copy lại token.

#### 3) Join các node agent

Trên mỗi node còn lại:

```bash
sudo bash install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
```

Script sẽ in log cuối của `rke2-agent` để bạn kiểm tra nhanh.

#### 4) Kiểm tra cụm từ node server

Trên node server:

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide
```

### Cài Rancher (tuỳ chọn)

Chạy trên node server (hoặc node nào có `kubectl` trỏ tới cluster):

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
sudo bash install_rancher.sh <NODE_IP>
```

Script sẽ:
- Cài Helm
- Cài cert-manager (đang dùng `v1.14.5`)
- Chỉnh `local-path-provisioner` lưu PV vào `/data/local-path`
- Cài Rancher với:
  - **hostname**: `<NODE_IP>.sslip.io`
  - **bootstrapPassword**: `admin`
  - **replicas**: `1`
  - **persistence**: bật (`10Gi`, `local-path`)

Truy cập:
- `https://<NODE_IP>.sslip.io`

Tài khoản mặc định:
- user: `admin`
- pass: `admin`

### Xử lý lỗi nhanh

- **Server RKE2 chưa lên**:
  - `sudo systemctl status rke2-server --no-pager`
  - `sudo journalctl -u rke2-server -n 200 --no-pager`
- **Agent không join được**:
  - Kiểm tra agent → server truy cập được **9345/tcp**
  - Kiểm tra token đúng
  - `sudo journalctl -u rke2-agent -n 200 --no-pager`
- **Không có kubectl**:
  - `kubectl` nằm ở `/var/lib/rancher/rke2/bin/kubectl`
  - Thêm vào `PATH` hoặc gọi trực tiếp
- **Rancher rollout bị timeout**:
  - `kubectl -n cert-manager get pods`
  - `kubectl -n cattle-system get pods`
  - `kubectl -n cattle-system get events --sort-by=.lastTimestamp | tail -n 50`

### Gỡ / dọn sạch node (NGUY HIỂM)

`rke2-clean-node.sh` sẽ dừng service, unmount các mount liên quan, và **xoá dữ liệu ở `/data` + nhiều đường dẫn hệ thống**.

Trước khi xoá sạch một node, bạn nên **loại node đó ra khỏi cluster** để tránh cluster bị “lệch trạng thái” hoặc gặp lỗi khó xử lý.

Chạy trên máy có `kubectl` truy cập được vào cluster (thường là node server):

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# 1) Không cho schedule pod mới lên node này
kubectl cordon <NODE_NAME>

# 2) Di chuyển workload ra khỏi node (tuỳ môi trường có thể cần chỉnh flags)
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data

# 3) Xoá object node khỏi cluster
kubectl delete node <NODE_NAME>
```

Lưu ý:
- Nếu node là **RKE2 server/control-plane**, đừng wipe nếu bạn chưa hiểu rõ ảnh hưởng tới quorum/etcd.
- Nếu drain bị kẹt vì PodDisruptionBudget (PDB), hãy xử lý PDB trước khi tiếp tục.

Chỉ chạy khi bạn chắc chắn:

```bash
sudo bash rke2-clean-node.sh
```

Script yêu cầu gõ `YES` để xác nhận.

### Lưu ý bảo mật

- Rancher mặc định mật khẩu `admin` → hãy đổi ngay sau khi đăng nhập.
- Kubeconfig đang để `0644` → tuỳ môi trường bạn có thể cần siết quyền truy cập.

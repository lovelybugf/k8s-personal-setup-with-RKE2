# RKE2 Kubernetes Homelab Bootstrap Scripts

Opinionated bootstrap scripts to stand up a small **RKE2** Kubernetes cluster and (optionally) install **Rancher** on top.

- **Target**: Homelabs, development, or personal clusters (quick setup, simple defaults)
- **Supported OS Families**:
  - **Debian/Ubuntu-like** (Debian, Ubuntu) using `apt`
  - **RHEL-like** (Red Hat Enterprise Linux, Rocky Linux, AlmaLinux, CentOS) using `dnf`/`yum`
- **Scope**: OS preparation, RKE2 server/agent setup, Rancher deployment, and node teardown.

---

## 📂 Repository Layout

To prevent OS command conflicts (such as package managers or firewall systems), the bootstrap scripts are cleanly separated into dedicated directories:

```text
.
├── rhel/                      # For RHEL, Rocky Linux, AlmaLinux, CentOS
│   ├── prepare.sh             # Sets up chronyd, SELinux Permissive/Disabled, NetworkManager, swap, modules
│   ├── install_rke2.sh        # Installs RKE2 (server/agent), symlinks kubectl/crictl, creates local-path dir
│   ├── get_token.sh           # Retrieves cluster join token
│   ├── install_rancher.sh     # Deploys Helm, cert-manager, local-path storage, and Rancher Server
│   ├── rke2-clean-node.sh     # Official killall/uninstall + force-deletes persistent directories
│   └── check_health.sh        # Configures local kubectl and performs cluster health checks
│
├── ubuntu/                    # For Debian, Ubuntu
│   ├── prepare.sh             # Sets up timesyncd, UFW disable, swap, modules
│   ├── install_rke2.sh        # Installs RKE2 (server/agent), symlinks kubectl/crictl, creates local-path dir
│   ├── get_token.sh           # Retrieves cluster join token
│   ├── install_rancher.sh     # Deploys Helm, cert-manager, local-path storage, and Rancher Server
│   ├── rke2-clean-node.sh     # Official killall/uninstall + force-deletes persistent directories
│   └── check_health.sh        # Configures local kubectl and performs cluster health checks
│
├── README.md                  # This documentation
└── troubleshooting_ip_fix.md  # Multi-NIC IP routing troubleshooting log and guide
```

---

## 🇺🇸 English Guide

### 📋 Prerequisites & Network
- **Permissions**: Root or sudo privileges on all nodes.
- **Port requirements**:
  - Open **6443/tcp** (Kubernetes API) and **9345/tcp** (RKE2 Supervisor) on the Server node.
  - Open **443/tcp** on the node running Rancher.
  - Allow inner-cluster CNI communication (e.g., Canal uses vxlan port **8472/udp**).

---

### 🚀 Step-by-Step Setup Guide

#### 0. Prepare the Operating System
Run the OS preparation script on **every node** (both Server and Agent).

*   **For Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/prepare.sh
    ```
*   **For RHEL-based OS**:
    ```bash
    sudo bash rhel/prepare.sh
    ```
    > [!IMPORTANT]
    > **For RHEL-based systems, you MUST reboot the node after running the script** (`sudo reboot`). This is mandatory for SELinux disable rules and NetworkManager unmanaged interface settings to take full effect.

#### 1. Initialize the first Server node
On the node chosen as the control-plane/Server:

*   **For Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/install_rke2.sh <NODE_IP> init
    ```
*   **For RHEL-based OS**:
    ```bash
    sudo bash rhel/install_rke2.sh <NODE_IP> init
    ```
*   *Note*: The script automatically links `kubectl` and `crictl` to `/usr/local/bin` and configures `crictl` for easy container management.

#### 2. Retrieve the Join Token
On the initialized Server node, print and copy the token:
*   **For Ubuntu/Debian**: `sudo bash ubuntu/get_token.sh`
*   **For RHEL-based OS**: `sudo bash rhel/get_token.sh`

#### 3. Join Agent nodes
On each additional worker/Agent node:

*   **For Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
    ```
*   **For RHEL-based OS**:
    ```bash
    sudo bash rhel/install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
    ```

#### 4. Verify the Cluster
On the Server node, check the status of your nodes:
```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide
```

---

### 🖥️ Install Rancher (Optional)
Run this script from the Server node (or any machine configured with access to `kubectl`):

*   **For Ubuntu/Debian**:
    ```bash
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    sudo bash ubuntu/install_rancher.sh <NODE_IP>
    ```
*   **For RHEL-based OS**:
    ```bash
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    sudo bash rhel/install_rancher.sh <NODE_IP>
    ```

**What it does:**
- Installs Helm and adds the `rancher-latest` repository.
- Deploys `cert-manager` (version pinned to `v1.14.5`).
- Reconfigures `local-path-provisioner` storage path mapping to `/data/local-path`.
- Deploys stateless Rancher Server pointing to `<NODE_IP>.sslip.io` with bootstrap password `admin`.

---

### ⚠️ Teardown / Clean Node
If you need to uninstall RKE2 and delete all cluster data, execute the clean-node script.

> [!CAUTION]
> This will wipe all containers, configurations, and persistent volumes under `/data`!

```bash
# For Ubuntu
sudo bash ubuntu/rke2-clean-node.sh

# For RHEL
sudo bash rhel/rke2-clean-node.sh
```

---

## 🇻🇳 Hướng dẫn Tiếng Việt

### 📋 Yêu cầu trước khi chạy & Cấu hình mạng
- **Quyền hạn**: Quyền Root hoặc Sudo trên tất cả các node.
- **Yêu cầu về Cổng (Ports)**:
  - Mở cổng **6443/tcp** (Kubernetes API) và **9345/tcp** (RKE2 Supervisor) trên Server node.
  - Mở cổng **443/tcp** trên node expose Rancher.
  - Cho phép traffic nội bộ cụm (ví dụ Canal dùng cổng vxlan **8472/udp**).

---

### 🚀 Quy trình triển khai từng bước

#### 0. Chuẩn bị hệ điều hành (Run on all nodes)
Chạy script chuẩn bị hệ thống trên **từng node** (cả Server và Agent).

*   **Với Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/prepare.sh
    ```
*   **Với các hệ điều hành nhân RHEL**:
    ```bash
    sudo bash rhel/prepare.sh
    ```
    > [!IMPORTANT]
    > **Với RHEL-based OS, bạn BẮT BUỘC phải khởi động lại máy** (`sudo reboot`) sau khi chạy script này để cấu hình tắt SELinux và nạp lại cấu hình bỏ qua card mạng ảo của NetworkManager có hiệu lực hoàn toàn.

#### 1. Khởi tạo node Server (Control-plane) đầu tiên
Trên node được chọn làm control-plane:

*   **Với Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/install_rke2.sh <NODE_IP> init
    ```
*   **Với RHEL-based OS**:
    ```bash
    sudo bash rhel/install_rke2.sh <NODE_IP> init
    ```
*   *Lưu ý*: Script tự động tạo liên kết động (symlink) đưa lệnh `kubectl` và `crictl` ra toàn hệ thống tại thư mục `/usr/local/bin` và cấu hình sẵn file socket của `crictl`.

#### 2. Lấy Token để Agent kết nối
Trên node Server, lấy token:
*   **Với Ubuntu/Debian**: `sudo bash ubuntu/get_token.sh`
*   **Với RHEL-based OS**: `sudo bash rhel/get_token.sh`

#### 3. Join các node Agent (Worker)
Trên các node Agent còn lại, chạy lệnh trỏ về IP của Server kèm Token:

*   **Với Ubuntu/Debian**:
    ```bash
    sudo bash ubuntu/install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
    ```
*   **Với RHEL-based OS**:
    ```bash
    sudo bash rhel/install_rke2.sh <NODE_IP> join <SERVER_IP> <TOKEN>
    ```

#### 4. Kiểm tra cụm K8s
Từ node Server, chạy lệnh kiểm tra trạng thái các node:
```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide
```

---

### 🖥️ Cài đặt giao diện Rancher (Tùy chọn)
Chạy script này từ node Server (hoặc bất kỳ máy nào cấu hình sẵn file `KUBECONFIG` trỏ về cụm):

*   **Với Ubuntu/Debian**:
    ```bash
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    sudo bash ubuntu/install_rancher.sh <NODE_IP>
    ```
*   **Với RHEL-based OS**:
    ```bash
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    sudo bash rhel/install_rancher.sh <NODE_IP>
    ```

---

### ⚠️ Gỡ cài đặt / Dọn sạch Node (Teardown)
Khi cần gỡ cài đặt RKE2 và xóa toàn bộ dữ liệu cụm để cài lại:

> [!CAUTION]
> Thao tác này sẽ xóa sạch các container, cấu hình và dữ liệu Persistent Volumes lưu trong phân vùng `/data`!

```bash
# Cho Ubuntu/Debian
sudo bash ubuntu/rke2-clean-node.sh

# Cho RHEL-based
sudo bash rhel/rke2-clean-node.sh
```

---

## 🔒 Security & Best Practices / Lưu ý bảo mật
- **Rancher Password**: Rancher được bootstrap với mật khẩu mặc định là `admin`. **Thay đổi mật khẩu quản trị ngay lập tức** trong lần đăng nhập đầu tiên.
- **Kubeconfig Mode**: Để thuận tiện cho môi trường test/homelab, quyền truy cập tệp Kubeconfig (`/etc/rancher/rke2/rke2.yaml`) được cấu hình mặc định là `0644`. Trong môi trường production, hãy siết chặt quyền (`chmod 600`) để bảo vệ cụm tránh truy cập trái phép.

# 📓 Nhật Ký Khắc Phục Lỗi Định Tuyến IP (Multi-NIC) Cụm RKE2

Tài liệu này ghi lại chi tiết sự cố lệch IP mạng nội bộ (Multi-NIC) xảy ra trong quá trình triển khai cụm RKE2 Kubernetes, nguyên nhân cốt lõi và các bước đã thực hiện để khắc phục triệt để.

---

## 1. 🚨 Triệu Chứng Sự Cố (Symptoms)
Trong quá trình triển khai cụm RKE2 với 1 Master (`172.25.250.20`), 1 Worker (`172.25.250.30`) và 1 Load Balancer (`172.25.250.100`), hệ thống gặp các lỗi sau:

1.  **Lỗi Pod mạng trên Worker**: Pod quản lý mạng CNI (`rke2-canal-xxxx`) trên máy Worker liên tục bị kẹt ở trạng thái `Init:Error` hoặc `Init:CrashLoopBackOff`.
2.  **Lỗi kẹt Container**: Các Pod ứng dụng (`ngin-test`, Ingress Nginx) được schedule sang máy Worker bị kẹt vô hạn ở trạng thái `ContainerCreating` (không thể nhận IP).
3.  **Lỗi kết nối từ Master sang Worker**: Khi đứng từ Master gọi lệnh lấy log Pod trên Worker (`kubectl logs -n kube-system <pod-name>`), hệ thống báo lỗi:
    ```text
    Error from server: Get "https://192.168.40.136:10250/...": proxy error from 127.0.0.1:9345 while dialing 192.168.40.136:10250, code 502: 502 Bad Gateway
    ```
4.  **Lỗi kẹt etcd khi đổi IP**: Khi sửa trực tiếp IP trong file cấu hình `/etc/rancher/rke2/config.yaml` và restart, dịch vụ `rke2-server` bị kẹt ở trạng thái `activating (start)` vĩnh viễn với thông báo log:
    ```text
    Failed to test etcd connection: this server is not a member of the etcd cluster. Found [node-172-25-250-20-xxx=https://192.168.40.136:2380], expected [...]
    ```

---

## 2. 🔍 Nguyên Nhân Cốt Lõi (Root Cause)

*   **Xung đột Nhiều Card Mạng (Multi-NIC)**: 
    Mỗi máy ảo có 2 card mạng: 1 card NAT kết nối ra internet (`192.168.40.x`) và 1 card Host-Only/Private kết nối nội bộ giữa các máy ảo (`172.25.250.x`).
    Mặc định, nếu không được cấu hình chỉ định, RKE2 tự động lấy IP gắn liền với default route (card mạng ra internet `192.168.40.x`) để đăng ký node.
*   **Mất kết nối nội bộ cụm**:
    Do Node Master (`172.25.250.20`) không thể định tuyến/kết nối tới dải IP `192.168.40.x` của Worker, luồng giao tiếp Kubelet (cổng `10250`) và đường hầm mạng VXLAN của Canal CNI bị chặn hoàn toàn.
*   **Xung đột dữ liệu etcd**:
    Cơ sở dữ liệu etcd được khởi tạo ban đầu gắn liền với IP sai (`192.168.40.136`). Khi thay đổi IP cấu hình ở runtime, etcd phát hiện sự sai lệch thành viên (member mismatch) và từ chối đồng bộ, dẫn đến cụm bị kẹt không thể khởi động lại.

---

## 3. 🛠️ Giải Pháp Đã Thực Hiện (Resolution)

Để giải quyết triệt để sự cố trên, chúng ta đã thực hiện tối ưu hóa cấu hình tự động và dọn dẹp hệ thống như sau:

### Bước 1: Cập nhật biến cấu hình mạng `node-ip` vào Script
Đã chỉnh sửa tệp tin `install_rke2.sh` trên cả Ubuntu và RHEL để tự động ghi đè tham số `node-ip` vào file `/etc/rancher/rke2/config.yaml` dựa trên IP nội bộ truyền vào:
```yaml
# Nội dung config.yaml sau khi tối ưu
data-dir: /data/rke2
write-kubeconfig-mode: "0644"
node-ip: 172.25.250.20       # Ép RKE2 luôn bind và quảng bá đúng IP này
tls-san:
  - 172.25.250.20
  - 172.25.250.30              # Tự động thêm IP của Load Balancer
```

### Bước 2: Hỗ trợ tự động điền IP Load Balancer vào `tls-san`
Tối ưu hóa cú pháp khởi tạo Master để nhận tham số thứ 3 làm IP của Load Balancer và ghi tự động vào chứng chỉ SSL:
```bash
sudo bash install_rke2.sh <IP_NỘI_BỘ_MASTER> init <IP_LOAD_BALANCER>
```

### Bước 3: Dọn dẹp sạch dữ liệu cũ và Triển khai lại từ đầu (Clean Reinstall)
Để giải quyết triệt để lỗi kẹt etcd do đổi IP, chúng ta đã tiến hành wipe sạch dữ liệu cũ trên cả 2 máy ảo:
1.  **Dọn dẹp Master (VM 1)**: Chạy `rke2-clean-node.sh` để xóa phân vùng dữ liệu cũ `/data/rke2/` và cơ sở dữ liệu etcd lỗi.
2.  **Khởi tạo lại Master**: Chạy lệnh cài đặt mới trỏ đúng IP nội bộ và IP Load Balancer.
3.  **Dọn dẹp Worker (VM 2)**: Chạy `rke2-clean-node.sh`.
4.  **Join lại Worker**: Chạy kết nối sử dụng Token mới sinh ra từ Master.

### Bước 4: Tạo Script kiểm tra sức khỏe tự động (`check_health.sh`)
Viết thêm script `check_health.sh` giúp tự động cấu hình tệp tin xác thực `~/.kube/config` cho người dùng hiện tại và thực hiện quét nhanh sức khỏe của cụm (API connection, Node status, Unhealthy Pods).

---

## 4. 📈 Kết Quả Sau Cùng (Verification)
Sau khi áp dụng các giải pháp trên:
*   Cột `INTERNAL-IP` của cả Master và Worker đã nhận diện chuẩn xác dải mạng nội bộ `172.25.250.x`.
*   Mạng Canal khởi tạo thành công (`Ready 2/2 Running`), toàn bộ các Pod ứng dụng khác chuyển sang trạng thái xanh khỏe mạnh.
*   Lệnh `kubectl logs` và `kubectl exec` hoạt động bình thường, không còn lỗi Bad Gateway.
*   Cụm sẵn sàng kết nối tới Load Balancer và cài đặt Rancher.

# 📓 Nhật Ký Sửa Lỗi Lệch IP Cụm RKE2 (Multi-NIC)

Ghi nhanh sự cố lệch IP card mạng nội bộ và cách sửa đổi.

## 1. Lỗi gặp phải
*   Cụm tự nhận IP card NAT (`192.168.40.136`) thay vì IP nội bộ (`172.25.250.x`).
*   **Hậu quả**: Pod mạng `rke2-canal` kẹt `Init:CrashLoopBackOff`; lệnh `kubectl logs` lỗi `502 Bad Gateway`.
*   **Lỗi etcd**: Khi đổi IP cấu hình, database etcd cũ bị lệch cấu hình thành viên gây treo khởi động RKE2.

## 2. Cách khắc phục
1.  **Chỉ định `node-ip`**: Ép tham số `node-ip: <IP_NỘI_BỘ>` vào `/etc/rancher/rke2/config.yaml` ở cả 2 node.
2.  **Reset cụm**: Chạy script để xóa sạch database etcd bị lỗi cấu hình cũ:
    ```bash
    sudo bash rke2-clean-node.sh
    ```
3.  **Cài đặt lại Master**: Chạy script mới, truyền thêm IP Load Balancer vào đối số thứ 3 để tự cấu hình `tls-san`:
    ```bash
    sudo bash install_rke2.sh <IP_MASTER> init <IP_LOAD_BALANCER>
    ```
4.  **Cài đặt lại Worker**: Chạy script join vào Master với Token mới.
5.  **Kiểm tra**: Chạy `bash check_health.sh` để cấu hình nhanh `kubectl` và kiểm tra cụm.

## 3. Sự cố Webhook Rancher chặn cài đặt CNI Calico
*   **Triệu chứng**: Khi chuyển đổi CNI sang `calico` hoặc cài đặt lại cụm mạng, các Pod của `coredns` bị kẹt ở trạng thái `ContainerCreating`. Logs của `tigera-operator` báo lỗi:
    `admission webhook "rancher.cattle.io.namespaces.create-non-kubesystem" denied the request: Unauthorized`
*   **Nguyên nhân**: Webhook bảo mật của Rancher tự động kiểm tra quyền tạo Namespace. Tài khoản `ServiceAccount` của `tigera-operator` khi cố tạo namespace `calico-system` chưa được phân quyền trong hệ thống Rancher nên bị Webhook chặn lại. Do không tạo được namespace, cụm mạng Calico không thể triển khai.
*   **Cách khắc phục**:
    1. Xóa cấu hình Webhook đang chặn của Rancher (Rancher sẽ tự động tạo lại nó sau đó):
       ```bash
       kubectl delete validatingwebhookconfiguration rancher.cattle.io
       kubectl delete mutatingwebhookconfiguration rancher.cattle.io
       ```
    2. Khởi động lại Operator để kích hoạt việc cài đặt Calico ngay lập tức:
       ```bash
       kubectl rollout restart deployment/tigera-operator -n tigera-operator
       ```
    3. (Cách Bypass không cần xóa): Tạo thủ công namespace `calico-system` bằng quyền admin tối cao trước khi cài đặt Rancher (khi webhook chưa chạy). Lúc này Operator chỉ cần deploy Pod vào mà không cần gọi lệnh tạo mới:
       ```bash
       kubectl create namespace calico-system
       ```

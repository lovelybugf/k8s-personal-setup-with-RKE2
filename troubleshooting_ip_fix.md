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

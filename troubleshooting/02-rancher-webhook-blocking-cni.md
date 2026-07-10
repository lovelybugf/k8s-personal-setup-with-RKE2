# 📓 Sự Cố Webhook Rancher Chặn Cài Đặt CNI Calico

Ghi nhanh lỗi xung đột nhãn quyền tạo Namespace giữa Webhook bảo mật của Rancher và CNI Calico (Tigera Operator).

## 1. Triệu chứng
*   Khi chuyển đổi CNI sang `calico` hoặc cài đặt lại cụm mạng, các Pod của `coredns` bị kẹt ở trạng thái `ContainerCreating`.
*   Nhật ký (Logs) của `tigera-operator` báo lỗi:
    `admission webhook "rancher.cattle.io.namespaces.create-non-kubesystem" denied the request: Unauthorized`
*   Thư mục/Namespace `calico-system` không được tạo ra và không có Pod Calico nào được khởi tạo.

## 2. Nguyên nhân
*   Webhook bảo mật của Rancher (`rancher.cattle.io`) tự động kích hoạt tính năng kiểm tra quyền hạn khi tạo các Namespace mới (ngoại trừ hệ thống).
*   Tài khoản dịch vụ `ServiceAccount` của `tigera-operator` khi cố gắng tạo namespace `calico-system` chưa được đăng ký hay phân quyền trong Rancher API nên bị Webhook chặn đứng với mã lỗi `Unauthorized`.

## 3. Cách khắc phục và Bypass

### Cách 1: Xóa tạm thời cấu hình Webhook (Nhanh nhất)
Gỡ cấu hình Webhook của Rancher để giải phóng quyền tạo Namespace cho Operator (Rancher sẽ tự động tạo lại cấu hình Webhook này sau 1-2 phút):
```bash
# Xóa cấu hình Validating và Mutating Webhook
kubectl delete validatingwebhookconfiguration rancher.cattle.io
kubectl delete mutatingwebhookconfiguration rancher.cattle.io

# Khởi động lại Operator để nó tiến hành đồng bộ và tạo ngay namespace Calico
kubectl rollout restart deployment/tigera-operator -n tigera-operator
```

### Cách 2: Tạo trước Namespace (Bypass không cần xóa)
Để tránh bị Webhook chặn mà không cần can thiệp cấu hình, bạn có thể tạo thủ công namespace bằng tài khoản admin tối cao trước khi cài đặt Rancher (khi Webhook chưa hoạt động):
```bash
# Tạo thủ công namespace
kubectl create namespace calico-system
```
Khi Tigera Operator khởi chạy, nó thấy Namespace đã có sẵn nên chỉ việc sử dụng, không gọi lệnh `CREATE` Namespace mới và sẽ không kích hoạt Webhook.

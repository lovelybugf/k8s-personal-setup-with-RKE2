# Hướng dẫn Triển khai và Kiểm tra Docker Voting App trên Kubernetes (RKE2)

Chúng ta đã tái cấu trúc thành công thư mục [three-tier-app/](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app) thành cụm ứng dụng **Docker Voting App** hoàn chỉnh, tách biệt và chuẩn chỉ. Dưới đây là hướng dẫn cách triển khai và chạy thử trên cụm RKE2.

---

## 📂 Danh sách các file cấu hình đã được tạo mới
1. **[01-namespace.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/01-namespace.yaml)**: Định nghĩa namespace `dev-voting-app` cô lập tài nguyên.
2. **[02-secret.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/02-secret.yaml)**: Lưu thông tin tài khoản DB mặc định (`postgres` / `postgres`).
3. **[03-configmap.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/03-configmap.yaml)**: Lưu thông tin cấu hình Host kết nối.
4. **[04-database-storage.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/04-database-storage.yaml)**: Cấu hình `StorageClass` (local-storage) và `PersistentVolume` (postgres-local-pv) trỏ vào thư mục `/storage` trên Node 2 (`node-172-25-250-30`).
5. **[04-database-service.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/04-database-service.yaml)**: Headless Service tên `db` để các Pod tự tìm thấy DB qua DNS của Kubernetes.
6. **[04-database-statefulset.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/04-database-statefulset.yaml)**: StatefulSet cho PostgreSQL 15, yêu cầu dung lượng `15Gi` từ phân vùng `/storage`.
7. **[05-redis.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/05-redis.yaml)**: Khởi tạo hàng đợi Redis lưu tạm dữ liệu vote.
8. **[06-worker.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/06-worker.yaml)**: Worker xử lý ngầm (.NET) đọc phiếu từ Redis và lưu trữ lâu dài vào Postgres.
9. **[07-vote.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/07-vote.yaml)**: Frontend Python cho người dùng bình chọn (Cats vs Dogs).
10. **[08-result.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/08-result.yaml)**: Frontend NodeJS hiển thị biểu đồ kết quả thời gian thực.
11. **[09-ingress.yaml](file:///e:/k8s-personal-setup-with-RKE2/three-tier-app/09-ingress.yaml)**: Ingress định tuyến dựa trên tên miền động sslip.io.

---

## 🚀 Các bước Triển khai

Truy cập vào máy control-plane (Server) của bạn và chạy lệnh sau để triển khai toàn bộ thư mục:

```bash
# Cấu hình KUBECONFIG
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Apply toàn bộ thư mục cấu hình
kubectl apply -f three-tier-app/
```

### Kết quả hiển thị mong đợi:
```text
namespace/dev-voting-app created
secret/db-secret created
configmap/app-configmap created
storageclass.storage.k8s.io/local-storage created
persistentvolume/postgres-local-pv created
service/db created
statefulset.apps/postgres created
service/redis created
deployment.apps/redis created
deployment.apps/worker created
service/vote created
deployment.apps/vote created
service/result created
deployment.apps/result created
ingress.networking.k8s.io/voting-app-ingress created
```

---

## 🔍 Kiểm tra Trạng thái Triển khai

### 1. Kiểm tra các Pod hoạt động:
```bash
kubectl get pods -n dev-voting-app -o wide
```
> [!IMPORTANT]
> Pod `postgres-0` bắt buộc phải chạy trên Node `node-172-25-250-30` vì chúng ta đã thiết lập Node Affinity hướng ổ đĩa `/storage` vào Node này. Các Pod khác sẽ được tự động phân bổ đều trên toàn cụm.

### 2. Kiểm tra Persistent Volume Claim (PVC):
```bash
kubectl get pvc -n dev-voting-app
```
Bạn sẽ thấy trạng thái `Bound` trỏ về `postgres-local-pv` của ổ đĩa `/storage`.

### 3. Kiểm tra Logs của Worker để xác minh kết nối:
```bash
kubectl logs deployment/worker -n dev-voting-app
```
Logs hợp lệ sẽ báo:
`Connecting to db` và `Found database`, chứng minh worker đang đọc ghi dữ liệu thành công giữa Redis và Postgres.

---

## 🖥️ Trải nghiệm bình chọn thực tế

Vì chúng ta cấu hình Ingress sslip.io tự động phân giải IP `10.1.71.250` trên mạng nội bộ của bạn, bạn có thể truy cập trực tiếp từ máy tính cá nhân của mình bằng trình duyệt:

1. **Trang Bình Chọn (Vote)**:
   Truy cập: **[http://vote.10.1.71.250.sslip.io](http://vote.10.1.71.250.sslip.io)**
   *(Bạn có thể bấm chọn chọn "Cats" hoặc "Dogs")*

2. **Trang Biểu Đồ Kết Quả (Result)**:
   Truy cập: **[http://result.10.1.71.250.sslip.io](http://result.10.1.71.250.sslip.io)**
   *(Bạn sẽ thấy biểu đồ cập nhật phần trăm thời gian thực của phiếu bạn vừa vote!)*

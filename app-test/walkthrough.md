# Hướng dẫn Triển khai và Kiểm tra Gitea + PostgreSQL trên Kubernetes (RKE2)

Chúng ta đã cấu hình thành công cụm ứng dụng **Gitea (Git Server cá nhân)** kết nối với **PostgreSQL** trong namespace `dev-gitea`. Dưới đây là hướng dẫn triển khai và chạy thử nghiệm.

---

## 📂 Danh sách các file cấu hình trong thư mục `app-test/`
1. **[01-namespace.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/01-namespace.yaml)**: Định nghĩa namespace `dev-gitea` cô lập tài nguyên.
2. **[02-secret.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/02-secret.yaml)**: Lưu thông tin tài khoản DB (`gitea` / `gitea`).
3. **[03-configmap.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/03-configmap.yaml)**: Lưu thông tin cấu hình Host và Database.
4. **[04-database-storage.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/04-database-storage.yaml)**: Cấu hình `StorageClass` (local-storage) và `PersistentVolume` (postgres-local-pv) trỏ vào thư mục `/storage` trên Node 2 (`node-172-25-250-30`).
5. **[04-database-service.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/04-database-service.yaml)**: Headless Service tên `db` để Gitea tự tìm thấy DB qua DNS của Kubernetes.
6. **[04-database-statefulset.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/04-database-statefulset.yaml)**: StatefulSet cho PostgreSQL 15, yêu cầu dung lượng `15Gi` từ phân vùng `/storage`.
7. **[05-gitea.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/05-gitea.yaml)**: Deployment Gitea (`gitea/gitea:1.21`) và Service `gitea` (cổng 3000). Sử dụng volume `hostPath` trỏ tới `/var/gitea-data` để tự động tạo thư mục và lưu trữ mã nguồn bền vững.
8. **[09-ingress.yaml](file:///e:/k8s-personal-setup-with-RKE2/app-test/09-ingress.yaml)**: Ingress định tuyến dựa trên tên miền động sslip.io thông qua IP Load Balancer `10.1.71.250`.

---

## 🚀 Các bước Triển khai

### Bước 1: Dọn dẹp cụm cũ (Voting App)
Để giải phóng RAM cho cụm máy ảo của bạn, hãy chạy lệnh xóa namespace cũ trên máy Master (quyền root):
```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl delete namespace dev-voting-app
```

### Bước 2: Triển khai Gitea + Postgres
Copy đè thư mục `app-test` từ Windows sang `/home/ducnam` trên máy ảo, sau đó chạy lệnh:
```bash
kubectl apply -f /home/ducnam/app-test/
```

### Kết quả hiển thị mong đợi:
```text
namespace/dev-gitea created
secret/db-secret created
configmap/app-configmap created
storageclass.storage.k8s.io/local-storage configured
persistentvolume/postgres-local-pv configured
service/db created
statefulset.apps/postgres created
service/gitea created
deployment.apps/gitea created
ingress.networking.k8s.io/gitea-ingress created
```

---

## 🔍 Kiểm tra Trạng thái Triển khai

### 1. Kiểm tra các Pod hoạt động:
```bash
kubectl get pods -n dev-gitea -o wide
```
> [!IMPORTANT]
> Pod `postgres-0` sẽ chạy trên Node `node-172-25-250-30` (Worker Node), còn Pod `gitea-xxxx` sẽ chạy trên Node `node-172-25-250-20` (Master Node).
> Việc phân bổ này buộc Gitea và Database phải kết nối chéo qua CNI overlay network của cụm, giúp bạn thực hiện demo truyền thông mạng giữa 2 Node!

### 2. Kiểm tra Logs của Gitea để xác minh kết nối:
```bash
kubectl logs deployment/gitea -n dev-gitea --tail=50
```
Gitea khi khởi động sẽ tự tạo các bảng dữ liệu trong PostgreSQL và hiển thị log dạng:
`Routing: Registering route...` và bắt đầu lắng nghe thành công trên cổng `3000`.

---

## 🖥️ Trải nghiệm thực tế

Bạn mở trình duyệt trên máy cá nhân và truy cập trực tiếp bằng đường dẫn:

👉 **[http://gitea.10.1.71.250.sslip.io](http://gitea.10.1.71.250.sslip.io)**

1.  **Đăng ký tài khoản (Register)**:
    Bấm nút **Register** ở góc phải trên cùng để đăng ký tài khoản đầu tiên. (Tài khoản đầu tiên được đăng ký sẽ tự động có quyền Quản trị tối cao - Administrator).
2.  **Đăng nhập và Tạo Repository**:
    Sau khi đăng ký, hãy đăng nhập và bấm vào dấu **+** ở góc phải -> chọn **New Repository** để tạo thử một kho chứa code mới.
3.  **Kiểm tra tính bền vững dữ liệu**:
    Bạn có thể thử tạo một tệp tin `README.md` mới trong repository vừa tạo. Do dữ liệu được ghi đè lưu trữ trực tiếp vào phân vùng `/storage` trên máy Worker, ngay cả khi bạn khởi động lại cụm hoặc Pod bị xóa, mọi thông tin người dùng và mã nguồn đều sẽ không bị mất!

# Thiết lập phiên bản Flutter bằng FVM

Dự án này sử dụng SDK Dart yêu cầu `>=3.8.1 <4.0.0` (xem trong `pubspec.yaml`). File `pubspec.lock` cũng chỉ ra ràng buộc `flutter: ">=3.29.0"`. Vì vậy nên cố định phiên bản Flutter 3.32.4 (phiên bản stable mới tương thích với Dart 3.8.x).

> Khuyến nghị: Flutter 3.32.4 (stable) miễn là Dart tối thiểu 3.8.1.

## 1. Cài FVM

Windows (PowerShell):
```powershell
choco install fvm -y  # nếu đã cài Chocolatey
```
Hoặc cài qua Dart global activate:
```powershell
dart pub global activate fvm
# đảm bảo thư mục pub cache bin nằm trong PATH
```
Kiểm tra:
```powershell
fvm --version
```

## 2. Thêm cấu hình FVM cho dự án
Trong thư mục gốc dự án (`DoAnTotNghiep_HealthCare`):
```powershell
fvm use 3.32.4 --force
```
Lệnh này sẽ tạo `.fvm/` và file `.fvm/fvm_config.json` trỏ tới phiên bản Flutter đã chọn.

Để tải SDK (nếu chưa có):
```powershell
fvm install 3.32.4
```

## 3. Thiết lập IDE
- VS Code: Cài extension `FVM` hoặc chỉnh `settings.json`:
```json
{
  "dart.flutterSdkPath": ".fvm\\versions\\3.32.4"
}
```
- Android Studio: Vào Flutter SDK path chọn tới: `<project>/.fvm/versions/3.29.0`.

## 4. Chạy lệnh Flutter qua FVM
Luôn dùng tiền tố `fvm flutter` để chắc chắn đúng phiên bản:
```powershell
fvm flutter --version
fvm flutter pub get
fvm flutter analyze
fvm flutter run -d chrome
fvm flutter run -d windows
fvm flutter build apk --release
```

Có thể thêm script ngắn gọn trong PowerShell profile hoặc dùng alias.

## 5. Cấu hình PATH (tùy chọn)
Không bắt buộc, nhưng nếu muốn gõ trực tiếp `flutter` mà vẫn là bản của FVM:
```powershell
fvm doctor
```
Hoặc dùng shell hook (khuyến nghị vẫn dùng `fvm flutter` để tránh nhầm).

## 6. Đồng bộ nhóm
Commit các file sau để mọi người tự động nhận phiên bản:
- `.fvm/fvm_config.json`
- (Không commit toàn bộ SDK trong `.fvm/versions/...`)

Thêm vào `.gitignore` (nếu chưa có):
```
.fvm/flutter_sdk
```
FVM mặc định sinh symbolic link `./.fvm/flutter_sdk`; tránh commit SDK để nhẹ repo.

## 7. Kiểm tra nhanh môi trường
```powershell
fvm flutter doctor -v
```
Đảm bảo:
- Dart >= 3.8.1
- Flutter 3.32.4
- Android toolchain OK
- Chrome (nếu build web)
- Visual Studio (nếu build Windows)

## 8. Clean & Re-gen khi đổi phiên bản
Nếu vừa chuyển phiên bản hoặc gặp lỗi build:
```powershell
fvm flutter clean
fvm flutter pub get
fvm flutter pub run build_runner build --delete-conflicting-outputs  # nếu có codegen
```

## 9. FAQ
| Vấn đề | Cách xử lý |
|--------|------------|
| Flutter báo sai version | Chắc chắn bạn dùng `fvm flutter ...` thay vì `flutter` hệ thống |
| IDE vẫn nhận SDK cũ | Restart IDE hoặc sửa lại đường dẫn SDK như phần 3 |
| Cache package lỗi | Xóa `.dart_tool` rồi `fvm flutter pub get` |
| Web build không chạy | Kiểm tra bật web: `fvm flutter config --enable-web` |

## 10. Gợi ý thêm (tuỳ chọn)
Tạo file `.tool-versions` (cho asdf) hoặc `Makefile` để chuẩn hoá CI/CD nếu cần.

---
Sau khi làm xong các bước trên, người khác chỉ cần:
```powershell
git clone <repo>
cd DoAnTotNghiep_HealthCare
fvm install 3.32.4
fvm flutter pub get
fvm flutter run
```
Là chạy được dự án với đúng phiên bản.

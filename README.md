# Healthcare App - Flutter Firebase Authentication

## 📱 Mô tả Project
Ứng dụng Healthcare được xây dựng bằng Flutter với tích hợp Firebase Authentication, cung cấp các chức năng đăng ký, đăng nhập và quản lý người dùng.

## ✨ Tính năng
- **Đăng ký tài khoản** với email và password
- **Đăng nhập** với email và password  
- **User Profile Management** với UserModel và Firestore
- **Role-based System** (Bệnh nhân và Bác sĩ)
- **Disease Focus Selection** cho từng user
- **User Setup Screen** sau khi đăng ký
- **Đăng xuất** an toàn
- **Validation form** với thông báo lỗi rõ ràng
- **UI/UX** Material Design với màu chủ đạo xanh dương (#1976D2)
- **Responsive design** thích ứng với nhiều kích thước màn hình
- **Auto-login** tự động đăng nhập khi mở app
- **Error handling** xử lý lỗi với SnackBar

## 🏗️ Cấu trúc Project

```
lib/
├── main.dart                           # Entry point chính với Firebase
├── main_demo.dart                      # Entry point demo không cần Firebase
├── components/
│   └── base_page/
│       └── base_page.dart              # Trang chính sau khi đăng nhập
├── data/
│   ├── models/
│   │   └── user_model.dart             # User Model với UserRole và DiseaseFocus
│   ├── resources/
│   │   └── gene/
│   │       └── app_colors.dart         # Định nghĩa màu sắc app
│   └── services/
│       ├── auth_service.dart           # Firebase Authentication service
│       ├── user_service.dart           # Firestore User management service
│       └── doctor_service.dart         # Firestore Doctor management service
└── screens/
    ├── login/
    │   └── login_screen.dart           # Màn hình đăng nhập
    ├── register/
    │   └── register_screen.dart        # Màn hình đăng ký
    └── user_setup/
        └── user_setup_screen.dart      # Màn hình setup thông tin user
```

## 🚀 Cách chạy Project

### 1. Cài đặt dependencies
```bash
flutter pub get
```

### 2. Chạy phiên bản Demo (không cần Firebase)
```bash
# Sử dụng main_demo.dart để test UI
flutter run lib/main_demo.dart
```

**Thông tin đăng nhập demo:**
- Email: bất kỳ email hợp lệ
- Password: `123456`

### 3. Chạy phiên bản đầy đủ (cần Firebase)
1. Làm theo hướng dẫn trong `FIREBASE_SETUP.md`
2. Setup Firebase project và add configuration files
3. Chạy app:
```bash
flutter run
```

## 🔧 Setup Firebase

Xem file `FIREBASE_SETUP.md` để biết hướng dẫn chi tiết setup Firebase.

### Tóm tắt:
1. Tạo Firebase project
2. Enable Authentication với Email/Password
3. Add Android app với package name: `com.example.healthcare`
4. Download và copy `google-services.json` vào `android/app/`
5. Cập nhật build.gradle files

## 🎨 Design System

### Màu sắc chính
- **Primary**: #1976D2 (Blue)
- **Primary Light**: #63A4FF  
- **Primary Dark**: #004BA0
- **Background**: #F5F5F5
- **Surface**: #FFFFFF
- **Error**: #E53935
- **Success**: #4CAF50

### Typography
- **Title**: 28px, Bold
- **Subtitle**: 16px, Regular
- **Body**: 14px, Regular
- **Button**: 16px, Bold

## 📂 Files Chính

### `lib/main.dart`
Entry point chính với Firebase initialization và AuthWrapper để quản lý trạng thái đăng nhập.

### `lib/data/services/auth_service.dart`
Service class xử lý tất cả logic Firebase Authentication:
- Register với email/password
- Login với email/password  
- Logout
- Error handling và validation

### `lib/screens/login/login_screen.dart`
Màn hình đăng nhập với:
- Form validation
- Loading state
- Error handling
- Navigation đến register screen

### `lib/screens/register/register_screen.dart`
Màn hình đăng ký với:
- Form validation (email, password, confirm password)
- Loading state
- Error handling
- Navigation về login screen

### `lib/components/base_page/base_page.dart`
Trang chính sau khi đăng nhập với:
- Bottom navigation với 3 tabs
- Home tab với quick actions
- Profile tab với thông tin user
- Settings tab với các tùy chọn
- Logout functionality

## 🧪 Testing

### Test UI Demo
```bash
flutter run lib/main_demo.dart
```
- Sử dụng password `123456` với bất kỳ email hợp lệ nào
- Test được toàn bộ UI flow mà không cần Firebase

### Test Firebase Integration  
```bash
flutter run
```
- Cần setup Firebase trước
- Test được đầy đủ authentication flow

## 📋 Checklist Hoàn thành

✅ **Authentication**
- [x] Email/Password registration
- [x] Email/Password login
- [x] Logout functionality
- [x] Auto-login with StreamBuilder

✅ **User Management**
- [x] UserModel với đầy đủ fields theo yêu cầu
- [x] UserRole enum (patient/doctor)
- [x] DiseaseFocus enum với 15 chuyên khoa
- [x] UserService với Firestore integration
- [x] User Setup Screen sau khi đăng ký
- [x] Profile management với role display

✅ **UI/UX**
- [x] Material Design
- [x] Responsive layout
- [x] Color scheme (#1976D2)
- [x] Form validation
- [x] Loading states
- [x] Error handling với SnackBar
- [x] Role-based UI components

✅ **Navigation**
- [x] Login ↔ Register navigation
- [x] Register → UserSetup navigation
- [x] UserSetup → BasePage navigation
- [x] Logout → Login navigation

✅ **Code Structure**
- [x] Service layer cho Auth logic
- [x] UserModel với JSON serialization
- [x] UserService với CRUD operations
- [x] Reusable color definitions
- [x] Organized folder structure
- [x] Clean code practices

## 🔜 Next Steps

- [ ] Add forgot password functionality
- [ ] Add Google/Facebook login
- [ ] Add user profile management
- [ ] Add email verification
- [ ] Add push notifications
- [ ] Add offline support
- [ ] Add unit/widget tests

## 📞 Support

Nếu gặp vấn đề, vui lòng:
1. Kiểm tra `FIREBASE_SETUP.md` cho Firebase setup
2. Thử chạy demo version trước
3. Kiểm tra console logs để debug errors

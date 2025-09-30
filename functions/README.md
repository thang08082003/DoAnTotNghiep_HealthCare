# Healthcare Firebase Cloud Functions

## Setup

1. Install dependencies:
```bash
npm install
```

2. Deploy functions:
```bash
npm run deploy
```

## Available Functions

### User Management

#### `getDoctorsBySpecialty`
Lấy danh sách bác sĩ theo chuyên khoa.
```javascript
// Call from Flutter
final result = await FirebaseFunctions.instance
  .httpsCallable('getDoctorsBySpecialty')
  .call({'specialty': 'Cardiology'});
```

#### `getDoctorsByDiseaseFocus`
Lấy bác sĩ theo disease focus (tương thích với Flutter app hiện tại).
```javascript
// Call from Flutter
final result = await FirebaseFunctions.instance
  .httpsCallable('getDoctorsByDiseaseFocus')
  .call({'diseaseFocus': 'cardiology'});
```

#### `getAllDoctors`
Lấy tất cả bác sĩ.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('getAllDoctors')
  .call();
```

#### `updateUserProfile`
Cập nhật profile user.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('updateUserProfile')
  .call({
    'userId': 'user123',
    'updateData': {'name': 'New Name'}
  });
```

#### `assignDoctorToPatient`
Assign bác sĩ cho bệnh nhân.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('assignDoctorToPatient')
  .call({
    'patientId': 'patient123',
    'doctorId': 'doctor456'
  });
```

### Appointment Management

#### `createAppointment`
Tạo cuộc hẹn mới.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('createAppointment')
  .call({
    'patientId': 'patient123',
    'doctorId': 'doctor456',
    'appointmentDate': '2025-10-01T10:00:00Z',
    'notes': 'Khám tổng quát'
  });
```

#### `getUserAppointments`
Lấy danh sách cuộc hẹn của user.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('getUserAppointments')
  .call({
    'userId': 'user123',
    'role': 'patient' // hoặc 'doctor'
  });
```

### Utility Functions

#### `searchUsers`
Tìm kiếm users theo criteria.
```javascript
final result = await FirebaseFunctions.instance
  .httpsCallable('searchUsers')
  .call({
    'role': 'doctor',
    'specialty': 'Cardiology',
    'limit': 10
  });
```

#### `testAPI` (HTTP Function)
Test API endpoint.
```
GET https://your-project.cloudfunctions.net/testAPI
```

## Integration với Flutter

### 1. Cài đặt cloud_functions package

Thêm vào `pubspec.yaml`:
```yaml
dependencies:
  cloud_functions: ^4.6.0
```

### 2. Initialize trong Flutter

```dart
import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Lấy bác sĩ theo disease focus
  static Future<List<DoctorModel>> getDoctorsByDiseaseFocus(String diseaseFocus) async {
    try {
      final result = await _functions
          .httpsCallable('getDoctorsByDiseaseFocus')
          .call({'diseaseFocus': diseaseFocus});
      
      final List<dynamic> doctorsData = result.data['doctors'];
      return doctorsData
          .map((data) => DoctorModel.fromJson(data))
          .toList();
    } catch (e) {
      print('Error calling getDoctorsByDiseaseFocus: $e');
      rethrow;
    }
  }

  // Assign bác sĩ cho bệnh nhân
  static Future<bool> assignDoctorToPatient(String patientId, String doctorId) async {
    try {
      final result = await _functions
          .httpsCallable('assignDoctorToPatient')
          .call({
            'patientId': patientId,
            'doctorId': doctorId,
          });
      
      return result.data['success'] ?? false;
    } catch (e) {
      print('Error calling assignDoctorToPatient: $e');
      return false;
    }
  }
}
```

### 3. Sử dụng trong Provider

```dart
// Trong DiseaseDoctorSelectionProvider
Future<void> selectDiseaseFocus(DiseaseFocus focus) async {
  state = state.copyWith(
    selectedDiseaseFocus: focus,
    isLoading: true,
  );

  try {
    // Sử dụng Cloud Function thay vì direct Firestore query
    final doctors = await CloudFunctionsService
        .getDoctorsByDiseaseFocus(focus.value);
        
    state = state.copyWith(
      availableDoctors: doctors,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
  }
}
```

## Development

### Local Testing
```bash
npm run serve
```

### Deploy
```bash
npm run deploy
```

### View Logs
```bash
npm run logs
```

## Security Rules

Các Cloud Functions này yêu cầu user đã authenticate. Firestore security rules vẫn áp dụng cho direct database access.
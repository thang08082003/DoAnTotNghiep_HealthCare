import 'package:healthcare/data/models/user_model.dart';

/// Domain model representing a role-based help guide.
class HelpGuide {
  final String title; // e.g., "Hướng dẫn sử dụng (Bác sĩ)"
  final List<HelpSection> sections;

  const HelpGuide({required this.title, required this.sections});
}

/// A section in the help guide consisting of a title and multiple steps.
class HelpSection {
  final String title; // e.g., "Bắt đầu"
  final List<String> steps; // e.g., bullet steps/instructions

  const HelpSection({required this.title, required this.steps});
}

/// Simple factory for local default guides by role.
class DefaultHelpGuides {
  static HelpGuide forRole(UserRole role) {
    switch (role) {
      case UserRole.doctor:
        return _doctorGuideVi;
      case UserRole.patient:
        return _patientGuideVi;
    }
  }

  // Vietnamese: Doctor guide
  static const HelpGuide _doctorGuideVi = HelpGuide(
    title: 'Hướng dẫn sử dụng cho Bác sĩ',
    sections: [
      HelpSection(
        title: 'Bắt đầu',
        steps: [
          'Đăng nhập bằng tài khoản đã đăng ký.',
          'Hoàn tất hồ sơ: thêm chuyên khoa, số năm kinh nghiệm và mô tả.',
          'Kiểm tra thông báo để nhận các yêu cầu mới từ bệnh nhân.',
        ],
      ),
      HelpSection(
        title: 'Quản lý bệnh nhân',
        steps: [
          'Xem danh sách bệnh nhân đã được phân công.',
          'Mở hồ sơ bệnh nhân để xem chỉ số sức khỏe gần đây.',
          'Gửi nhận xét hoặc dặn dò trực tiếp từ màn hình trò chuyện.',
        ],
      ),
      HelpSection(
        title: 'Cuộc gọi tư vấn',
        steps: [
          'Chọn bệnh nhân và nhấn Gọi để bắt đầu cuộc gọi video.',
          'Cho phép quyền Micro và Camera nếu hệ thống yêu cầu.',
          'Kết thúc cuộc gọi và lưu ghi chú (nếu cần).',
        ],
      ),
      HelpSection(
        title: 'Bảo mật & tài khoản',
        steps: [
          'Thay đổi mật khẩu tại Cài đặt > Đổi mật khẩu.',
          'Cập nhật ảnh đại diện và thông tin liên hệ trong Hồ sơ.',
        ],
      ),
    ],
  );

  // Vietnamese: Patient guide
  static const HelpGuide _patientGuideVi = HelpGuide(
    title: 'Hướng dẫn sử dụng cho Bệnh nhân',
    sections: [
      HelpSection(
        title: 'Bắt đầu',
        steps: [
          'Đăng nhập bằng tài khoản đã đăng ký.',
          'Hoàn tất hồ sơ: thêm số điện thoại, tuổi, giới tính và tiền sử bệnh.',
          'Chọn “Bệnh theo dõi” để nhận gợi ý bác sĩ phù hợp.',
        ],
      ),
      HelpSection(
        title: 'Kết nối Health Connect',
        steps: [
          'Vào Hồ sơ > Cài đặt > Kết nối Health Connect.',
          'Cho phép quyền truy cập dữ liệu sức khỏe (bước/nhịp tim...).',
          'Chờ đồng bộ chỉ số và quay lại màn hình tổng quan để xem biểu đồ.',
        ],
      ),
      HelpSection(
        title: 'Liên hệ bác sĩ',
        steps: [
          'Chọn bác sĩ được gợi ý theo “Bệnh theo dõi”.',
          'Nhắn tin hoặc đặt cuộc gọi video để được tư vấn.',
          'Xem lại lịch sử trao đổi trong phần Trò chuyện.',
        ],
      ),
      HelpSection(
        title: 'Bảo mật & tài khoản',
        steps: [
          'Thay đổi mật khẩu tại Cài đặt > Đổi mật khẩu.',
          'Cập nhật ảnh đại diện và thông tin trong Hồ sơ.',
        ],
      ),
    ],
  );
}

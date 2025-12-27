import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../components/permissions/permission_card.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/permission_service.dart';

class PermissionsRequestScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsRequestScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionsRequestScreen> createState() =>
      _PermissionsRequestScreenState();
}

class _PermissionsRequestScreenState extends State<PermissionsRequestScreen> {
  bool _isRequesting = false;

  final List<PermissionItem> _permissions = [
    PermissionItem(
      permission: Permission.camera,
      title: 'Camera',
      description: 'Cần thiết để thực hiện video call với bác sĩ',
      icon: Icons.videocam,
      isRequired: true,
    ),
    PermissionItem(
      permission: Permission.microphone,
      title: 'Microphone',
      description: 'Cần thiết để thực hiện video call với bác sĩ',
      icon: Icons.mic,
      isRequired: true,
    ),
    PermissionItem(
      permission: Permission.phone,
      title: 'Điện thoại',
      description:
          'Đọc trạng thái cuộc gọi để tạm dừng video call khi có cuộc gọi đến',
      icon: Icons.phone,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.notification,
      title: 'Thông báo',
      description: 'Nhận thông báo về cuộc gọi, tin nhắn và chỉ định từ bác sĩ',
      icon: Icons.notifications,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.sensors,
      title: 'Cảm biến cơ thể',
      description: 'Đo nhịp tim và các chỉ số sức khỏe',
      icon: Icons.favorite,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.activityRecognition,
      title: 'Hoạt động thể chất',
      description: 'Theo dõi bước đi và hoạt động hàng ngày',
      icon: Icons.directions_walk,
      isRequired: false,
    ),
  ];

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    final granted = await PermissionService.requestAllPermissions();

    if (mounted) {
      setState(() => _isRequesting = false);

      if (granted) {
        widget.onPermissionsGranted();
      } else {
        // Check if permanently denied
        final permanentlyDenied =
            await PermissionService.hasPermissionsPermanentlyDenied();
        if (permanentlyDenied) {
          _showSettingsDialog();
        } else {
          _showErrorDialog();
        }
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cần cấp quyền'),
        content: const Text(
          'Một số quyền đã bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cần cấp quyền'),
        content: const Text(
          'Camera và Microphone là quyền bắt buộc để sử dụng tính năng video call. Vui lòng cấp quyền để tiếp tục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _skipPermissions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ qua cấp quyền?'),
        content: const Text(
          'Bạn có thể bỏ qua, nhưng một số tính năng như video call sẽ không hoạt động. Bạn có thể cấp quyền sau trong Cài đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPermissionsGranted();
            },
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.security,
                size: 80,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Cấp quyền truy cập',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ứng dụng cần một số quyền để hoạt động tốt nhất',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _permissions[index];
                    return PermissionCard(item: item);
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Cấp quyền',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _skipPermissions,
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

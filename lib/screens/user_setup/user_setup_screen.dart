import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/components/buttons/primary_button.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/router/app_router.dart';

class UserSetupScreen extends ConsumerStatefulWidget {
  final String uid;
  final String email;

  const UserSetupScreen({super.key, required this.uid, required this.email});

  @override
  ConsumerState<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends ConsumerState<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // Patient fields
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  String?
  _selectedGender; // internal codes: 'male','female','other' -> will be converted to Vietnamese label before saving
  // Doctor fields
  final _yearsExperienceController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _doctorDescriptionController = TextEditingController();
  String? _doctorGender; // 'male' | 'female' | 'other'

  UserRole _selectedRole = UserRole.patient;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _medicalHistoryController.dispose();
    _yearsExperienceController.dispose();
    _doctorPhoneController.dispose();
    _doctorDescriptionController.dispose();
    super.dispose();
  }

  String? _genderCodeToVietnamese(String? code) {
    switch (code) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return null;
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();

      if (mounted) {
        if (_selectedRole == UserRole.patient) {
          // Navigate to disease & doctor selection for patients
          AppRouter.pushDiseaseDoctorSelection(
            context,
            patientId: widget.uid,
            patientName: name,
            patientEmail: widget.email,
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            age: _ageController.text.trim().isNotEmpty
                ? int.tryParse(_ageController.text.trim())
                : null,
            gender: _genderCodeToVietnamese(_selectedGender),
            medicalHistory: _medicalHistoryController.text.trim().isNotEmpty
                ? _medicalHistoryController.text.trim()
                : null,
          );
        } else {
          // Navigate to specialty selection for doctors
          AppRouter.pushDoctorSpecialtySelection(
            context,
            doctorId: widget.uid,
            doctorName: name,
            doctorEmail: widget.email,
            yearsExperience: _yearsExperienceController.text.trim().isNotEmpty
                ? int.tryParse(_yearsExperienceController.text.trim())
                : null,
            phone: _doctorPhoneController.text.trim().isNotEmpty
                ? _doctorPhoneController.text.trim()
                : null,
            description: _doctorDescriptionController.text.trim().isNotEmpty
                ? _doctorDescriptionController.text.trim()
                : null,
            gender: _genderCodeToVietnamese(_doctorGender),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove user provider watch as it's not needed
    final isLoading = _isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      const Icon(
                        Icons.person_add_alt_1,
                        size: 80,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Hoàn thiện thông tin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng cung cấp thông tin cơ bản',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          if (value.trim().length < 2) {
                            return 'Tên phải có ít nhất 2 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Role selection
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bạn là:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              role: UserRole.patient,
                              icon: Icons.local_hospital,
                              title: 'Bệnh nhân',
                              subtitle: 'Tìm kiếm chăm sóc y tế',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleCard(
                              role: UserRole.doctor,
                              icon: Icons.medical_services,
                              title: 'Bác sĩ',
                              subtitle: 'Cung cấp dịch vụ y tế',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const SizedBox(height: 24),
                      // Dynamic extra fields per role
                      _buildExtraFieldsSection(),
                      const SizedBox(height: 24),

                      // Complete button
                      PrimaryButton(
                        text: 'Tiếp theo',
                        onPressed: _completeSetup,
                        isLoading: isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primaryColor : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.primaryColor
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? AppColors.primaryColor
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraFieldsSection() {
    if (_selectedRole == UserRole.patient) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thông tin bệnh nhân',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Số điện thoại',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Vui lòng nhập số điện thoại';
              }
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length != 10) return 'Phải có đúng 10 số';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Tuổi',
              prefixIcon: const Icon(Icons.cake_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tuổi';
              final n = int.tryParse(v);
              if (n == null || n < 0 || n > 120) return 'Tuổi không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Nam')),
              DropdownMenuItem(value: 'female', child: Text('Nữ')),
              DropdownMenuItem(value: 'other', child: Text('Khác')),
            ],
            decoration: InputDecoration(
              labelText: 'Giới tính',
              prefixIcon: const Icon(Icons.transgender),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => v == null ? 'Vui lòng chọn giới tính' : null,
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicalHistoryController,
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Tiền sử bệnh (tối đa 150 ký tự)',
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Vui lòng nhập tiền sử bệnh';
              }
              if (v.trim().length > 150) return 'Tối đa 150 ký tự';
              return null;
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thông tin bác sĩ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _doctorGender,
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Nam')),
              DropdownMenuItem(value: 'female', child: Text('Nữ')),
              DropdownMenuItem(value: 'other', child: Text('Khác')),
            ],
            decoration: InputDecoration(
              labelText: 'Giới tính',
              prefixIcon: const Icon(Icons.transgender),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => v == null ? 'Vui lòng chọn giới tính' : null,
            onChanged: (val) => setState(() => _doctorGender = val),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _doctorPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Số điện thoại',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Vui lòng nhập số điện thoại';
              }
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length != 10) return 'Phải có đúng 10 số';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _yearsExperienceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Số năm kinh nghiệm',
              prefixIcon: const Icon(Icons.timeline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số năm';
              final n = int.tryParse(v);
              if (n == null || n < 0) return 'Giá trị không hợp lệ';
              if (n >= 45) return 'Phải < 45 năm';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _doctorDescriptionController,
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Mô tả / Giới thiệu (tối đa 150 ký tự)',
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mô tả';
              if (v.trim().length > 150) return 'Tối đa 150 ký tự';
              return null;
            },
          ),
        ],
      );
    }
  }
}

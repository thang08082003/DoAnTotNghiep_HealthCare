import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/components/buttons/primary_button.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/router/app_router.dart';

class UserSetupScreen extends ConsumerStatefulWidget {
  final String uid;
  final String email;

  const UserSetupScreen({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  ConsumerState<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends ConsumerState<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  UserRole _selectedRole = UserRole.patient;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
          );
        } else {
          // Navigate to specialty selection for doctors
          AppRouter.pushDoctorSpecialtySelection(
            context,
            doctorId: widget.uid,
            doctorName: name,
            doctorEmail: widget.email,
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
          color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.1) : Colors.grey[100],
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
                color: isSelected ? AppColors.primaryColor : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primaryColor : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../router/app_router.dart';
import '../../../providers/doctor_specialty_selection_provider.dart';

class DoctorSpecialtySelectionScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorEmail;

  const DoctorSpecialtySelectionScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorEmail,
  });

  @override
  ConsumerState<DoctorSpecialtySelectionScreen> createState() => _DoctorSpecialtySelectionScreenState();
}

class _DoctorSpecialtySelectionScreenState extends ConsumerState<DoctorSpecialtySelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(doctorSpecialtySelectionProvider.notifier).resetSelection();
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionState = ref.watch(doctorSpecialtySelectionProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Chọn chuyên khoa'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services,
                            size: 40,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chào BS. ${widget.doctorName}!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hãy chọn chuyên khoa của bạn',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Specialty Selection
              const Text(
                'Chuyên khoa của bạn:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              ...Specialty.allSpecialties.map((specialty) => 
                _buildSpecialtyCard(specialty, selectionState),
              ),

              const SizedBox(height: 32),

              // Continue Button
              PrimaryButton(
                text: 'Hoàn thành đăng ký',
                onPressed: selectionState.canProceed && !selectionState.isLoading
                    ? _handleContinue
                    : null,
                isLoading: selectionState.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyCard(Specialty specialty, DoctorSpecialtySelectionState state) {
    final isSelected = state.selectedSpecialty == specialty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          ref.read(doctorSpecialtySelectionProvider.notifier)
              .selectSpecialty(specialty);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _getSpecialtyIcon(specialty),
                size: 32,
                color: isSelected ? AppColors.primaryColor : Colors.grey[600],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specialty.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryColor : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSpecialtyDescription(specialty),
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? AppColors.primaryColor : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    final result = await ref.read(doctorSpecialtySelectionProvider.notifier)
        .completeDoctorSetup(
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
          doctorEmail: widget.doctorEmail,
        );

    if (mounted) {
      if (result.success) {
        _showSnackBar(result.message!, isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && context.mounted) {
                                AppRouter.pushDashboard(context, userRole: UserRole.doctor);
        }
      } else {
        _showSnackBar(result.message!);
      }
    }
  }

  IconData _getSpecialtyIcon(Specialty specialty) {
    switch (specialty) {
      case Specialty.stress:
        return Icons.psychology;
      case Specialty.cardiology:
        return Icons.favorite;
      case Specialty.diagnosis:
        return Icons.medical_services;
    }
  }

  String _getSpecialtyDescription(Specialty specialty) {
    switch (specialty) {
      case Specialty.stress:
        return 'Chuyên về tâm lý và quản lý căng thẳng';
      case Specialty.cardiology:
        return 'Chuyên về tim mạch và huyết áp';
      case Specialty.diagnosis:
        return 'Chuyên về chẩn đoán và tư vấn tổng quát';
    }
  }
}
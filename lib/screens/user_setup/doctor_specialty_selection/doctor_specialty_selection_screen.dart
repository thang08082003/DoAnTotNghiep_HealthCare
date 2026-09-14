import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../providers/doctor_specialty_selection_provider.dart';
import '../../../providers/user_provider.dart';

class DoctorSpecialtySelectionScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorEmail;
  final int? yearsExperience;
  final String? phone;
  final String? description;
  final String? gender; // Vietnamese localized gender already

  const DoctorSpecialtySelectionScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorEmail,
    this.yearsExperience,
    this.phone,
    this.description,
    this.gender,
  });

  @override
  ConsumerState<DoctorSpecialtySelectionScreen> createState() =>
      _DoctorSpecialtySelectionScreenState();
}

class _DoctorSpecialtySelectionScreenState
    extends ConsumerState<DoctorSpecialtySelectionScreen> {
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

              ...Specialty.allSpecialties.map(
                (specialty) => _buildSpecialtyCard(specialty, selectionState),
              ),

              const SizedBox(height: 32),

              // Continue Button
              PrimaryButton(
                text: 'Hoàn thành đăng ký',
                onPressed:
                    selectionState.canProceed && !selectionState.isLoading
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

  Widget _buildSpecialtyCard(
    Specialty specialty,
    DoctorSpecialtySelectionState state,
  ) {
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
          ref
              .read(doctorSpecialtySelectionProvider.notifier)
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
                        color: isSelected
                            ? AppColors.primaryColor
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSpecialtyDescription(specialty),
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.primaryColor
                            : AppColors.textSecondary,
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
    final result = await ref
        .read(doctorSpecialtySelectionProvider.notifier)
        .completeDoctorSetup(
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
          doctorEmail: widget.doctorEmail,
          yearsExperience: widget.yearsExperience,
          phone: widget.phone,
          description: widget.description,
          gender: widget.gender,
        );

    if (mounted) {
      if (result.success) {
        _showSnackBar(result.message!, isError: false);

        // CRITICAL: Invalidate currentUserProvider to force refresh from Firestore
        // This ensures the app loads the newly created user data with correct role
        ref.invalidate(currentUserProvider);

        await Future.delayed(const Duration(seconds: 1));
        if (mounted && context.mounted) {
          // Navigate to root and let AuthWrapper handle navigation
          // It will check userExists, load fresh user data, and navigate to HomePage
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        _showSnackBar(result.message!);
      }
    }
  }

  IconData _getSpecialtyIcon(Specialty specialty) {
    switch (specialty) {
      case Specialty.diabetes:
        return Icons.water_drop;
      case Specialty.hypertension:
        return Icons.speed;
      case Specialty.cardiology:
        return Icons.favorite;
      case Specialty.respiratory:
        return Icons.air;
      case Specialty.gastroenterology:
        return Icons.restaurant;
      case Specialty.neurology:
        return Icons.psychology;
      case Specialty.orthopedics:
        return Icons.accessibility_new;
      case Specialty.dermatology:
        return Icons.face;
      case Specialty.mentalHealth:
        return Icons.self_improvement;
      case Specialty.obesity:
        return Icons.monitor_weight;
    }
  }

  String _getSpecialtyDescription(Specialty specialty) {
    switch (specialty) {
      case Specialty.diabetes:
        return 'Chuyên về điều trị tiểu đường và rối loạn nội tiết';
      case Specialty.hypertension:
        return 'Chuyên về quản lý huyết áp và bệnh nội khoa';
      case Specialty.cardiology:
        return 'Chuyên về tim mạch, nhịp tim và mạch máu';
      case Specialty.respiratory:
        return 'Chuyên về phổi, hô hấp và hen phế quản';
      case Specialty.gastroenterology:
        return 'Chuyên về tiêu hóa, gan mật và dạ dày';
      case Specialty.neurology:
        return 'Chuyên về thần kinh, não bộ và hệ thần kinh';
      case Specialty.orthopedics:
        return 'Chuyên về cơ xương khớp và chấn thương chỉnh hình';
      case Specialty.dermatology:
        return 'Chuyên về da liễu, mụn và bệnh da';
      case Specialty.mentalHealth:
        return 'Chuyên về tâm thần, lo âu và trầm cảm';
      case Specialty.obesity:
        return 'Chuyên về dinh dưỡng, giảm cân và béo phì';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../providers/disease_doctor_selection_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../data/models/user_model.dart';

class DiseaseDoctorSelectionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String? phone;
  final int? age;
  final String? gender;
  final String? medicalHistory;

  const DiseaseDoctorSelectionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    this.phone,
    this.age,
    this.gender,
    this.medicalHistory,
  });

  @override
  ConsumerState<DiseaseDoctorSelectionScreen> createState() =>
      _DiseaseDoctorSelectionScreenState();
}

class _DiseaseDoctorSelectionScreenState
    extends ConsumerState<DiseaseDoctorSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diseaseDoctorSelectionProvider.notifier).resetSelection();
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
    final selectionState = ref.watch(diseaseDoctorSelectionProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Chọn loại bệnh'),
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
                            Icons.person_add_alt_1,
                            size: 40,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào, ${widget.patientName}!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hãy chọn loại bệnh phù hợp',
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

              // Disease Focus Selection
              const Text(
                'Loại bệnh quan tâm:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              ...DiseaseFocus.allFocuses.map(
                (disease) => _buildDiseaseCard(disease, selectionState),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 16),

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

  Widget _buildDiseaseCard(
    DiseaseFocus disease,
    DiseaseDoctorSelectionState state,
  ) {
    final isSelected = state.selectedDiseaseFocus == disease;

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
              .read(diseaseDoctorSelectionProvider.notifier)
              .selectDiseaseFocus(disease);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _getDiseaseIcon(disease),
                size: 32,
                color: isSelected ? AppColors.primaryColor : Colors.grey[600],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.displayName,
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
                      _getDiseaseDescription(disease),
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
        .read(diseaseDoctorSelectionProvider.notifier)
        .completePatientSetup(
          patientId: widget.patientId,
          patientName: widget.patientName,
          patientEmail: widget.patientEmail,
          phone: widget.phone,
          age: widget.age,
          gender: widget.gender,
          medicalHistory: widget.medicalHistory,
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

  IconData _getDiseaseIcon(DiseaseFocus disease) {
    switch (disease) {
      case DiseaseFocus.stress:
        return Icons.psychology;
      case DiseaseFocus.cardiology:
        return Icons.favorite;
      case DiseaseFocus.diagnosis:
        return Icons.medical_services;
    }
  }

  String _getDiseaseDescription(DiseaseFocus disease) {
    switch (disease) {
      case DiseaseFocus.stress:
        return 'Quản lý căng thẳng và sức khỏe tâm lý';
      case DiseaseFocus.cardiology:
        return 'Chăm sóc sức khỏe tim mạch';
      case DiseaseFocus.diagnosis:
        return 'Chẩn đoán và tư vấn y tế tổng quát';
    }
  }
}

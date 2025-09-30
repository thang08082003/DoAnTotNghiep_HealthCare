import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/loading/loading_widget.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../router/app_router.dart';
import '../../../providers/disease_doctor_selection_provider.dart';

class DiseaseDoctorSelectionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;

  const DiseaseDoctorSelectionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
  });

  @override
  ConsumerState<DiseaseDoctorSelectionScreen> createState() => _DiseaseDoctorSelectionScreenState();
}

class _DiseaseDoctorSelectionScreenState extends ConsumerState<DiseaseDoctorSelectionScreen> {

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
        title: const Text('Chọn bệnh và bác sĩ'),
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
                                  'Hãy chọn loại bệnh và bác sĩ phù hợp',
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

              ...DiseaseFocus.allFocuses.map((disease) => 
                _buildDiseaseCard(disease, selectionState),
              ),

              const SizedBox(height: 32),

              // Doctor Selection
              if (selectionState.selectedDiseaseFocus != null) ...[
                const Text(
                  'Chọn bác sĩ:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                if (selectionState.isLoadingDoctors)
                  const LoadingWidget()
                else if (selectionState.availableDoctors.isEmpty)
                  _buildNoDoctorsCard()
                else
                  ...selectionState.availableDoctors.map((doctor) => 
                    _buildDoctorCard(doctor, selectionState),
                  ),
              ],

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

  Widget _buildDiseaseCard(DiseaseFocus disease, DiseaseDoctorSelectionState state) {
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
          ref.read(diseaseDoctorSelectionProvider.notifier)
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
                        color: isSelected ? AppColors.primaryColor : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDiseaseDescription(disease),
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

  Widget _buildDoctorCard(DoctorModel doctor, DiseaseDoctorSelectionState state) {
    final isSelected = state.selectedDoctor?.uid == doctor.uid;

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
          ref.read(diseaseDoctorSelectionProvider.notifier)
              .selectDoctor(doctor);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  doctor.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BS. ${doctor.name}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryColor : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chuyên khoa: ${doctor.specialty.displayName}',
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

  Widget _buildNoDoctorsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.orange[600],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có bác sĩ chuyên khoa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hiện tại chưa có bác sĩ nào cho chuyên khoa này. Bạn vẫn có thể tiếp tục đăng ký.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    final result = await ref.read(diseaseDoctorSelectionProvider.notifier)
        .completePatientSetup(
          patientId: widget.patientId,
          patientName: widget.patientName,
          patientEmail: widget.patientEmail,
        );

    if (mounted) {
      if (result.success) {
        _showSnackBar(result.message!, isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && context.mounted) {
                                AppRouter.pushDashboard(context, userRole: UserRole.patient);
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
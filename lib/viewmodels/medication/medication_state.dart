import '../../data/models/medication_model.dart';

/// State cho Medication Screen
class MedicationState {
  final List<Medication> medications;
  final bool isLoading;
  final String? error;
  final bool showActiveOnly;

  MedicationState({
    this.medications = const [],
    this.isLoading = false,
    this.error,
    this.showActiveOnly = true,
  });

  MedicationState copyWith({
    List<Medication>? medications,
    bool? isLoading,
    String? error,
    bool? showActiveOnly,
  }) {
    return MedicationState(
      medications: medications ?? this.medications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showActiveOnly: showActiveOnly ?? this.showActiveOnly,
    );
  }
}

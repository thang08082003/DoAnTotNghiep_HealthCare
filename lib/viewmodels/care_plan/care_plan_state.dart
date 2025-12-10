// State class để quản lý trạng thái của Care Plan
class CarePlanState {
  final DateTime selectedDate;
  final bool isLoading;
  final String? errorMessage;

  CarePlanState({
    required this.selectedDate,
    this.isLoading = false,
    this.errorMessage,
  });

  CarePlanState copyWith({
    DateTime? selectedDate,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CarePlanState(
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

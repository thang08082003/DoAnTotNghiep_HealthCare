import '../../data/models/care_plan_model.dart';

/// State class cho Goal Checklist
class GoalChecklistState {
  final HealthGoal goal;
  final bool isLoading;
  final String? errorMessage;
  final bool isAddingItem;

  GoalChecklistState({
    required this.goal,
    this.isLoading = false,
    this.errorMessage,
    this.isAddingItem = false,
  });

  GoalChecklistState copyWith({
    HealthGoal? goal,
    bool? isLoading,
    String? errorMessage,
    bool? isAddingItem,
  }) {
    return GoalChecklistState(
      goal: goal ?? this.goal,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isAddingItem: isAddingItem ?? this.isAddingItem,
    );
  }
}

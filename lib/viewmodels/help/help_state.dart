import '../../data/models/help_guide_model.dart';

class HelpState {
  final bool loading;
  final String? error;
  final HelpGuide? guide;

  const HelpState({
    required this.loading,
    required this.error,
    required this.guide,
  });

  const HelpState.initial() : loading = true, error = null, guide = null;

  HelpState copyWith({bool? loading, String? error, HelpGuide? guide}) {
    return HelpState(
      loading: loading ?? this.loading,
      error: error,
      guide: guide ?? this.guide,
    );
  }
}

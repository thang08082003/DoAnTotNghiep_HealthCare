import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/auto_analysis_service.dart';

/// Provider for AutoAnalysisService
final autoAnalysisServiceProvider = Provider<AutoAnalysisService>((ref) {
  return AutoAnalysisService();
});

/// Provider to track auto-analysis enabled state
final autoAnalysisEnabledProvider =
    StateNotifierProvider<AutoAnalysisNotifier, bool>((ref) {
      return AutoAnalysisNotifier(ref.read(autoAnalysisServiceProvider));
    });

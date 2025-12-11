import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

/// A reusable row widget for displaying steps with bullet points
///
/// Features:
/// - Bullet point indicator (•)
/// - Step text with secondary color
/// - Proper text wrapping
/// - Bottom padding for spacing
///
/// Usage:
/// ```dart
/// StepRow(text: 'Complete your profile information')
/// ```
class StepRow extends StatelessWidget {
  /// The step text to display
  final String text;

  const StepRow({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textPrimary)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../data/models/help_guide_model.dart';
import '../../data/resources/gene/app_colors.dart';
import 'step_row.dart';

/// A reusable card widget for displaying help guide sections
///
/// Features:
/// - White container with rounded corners
/// - Shadow elevation for depth
/// - Section title (bold, 16px)
/// - List of steps with bullet points
/// - Proper spacing between elements
///
/// Usage:
/// ```dart
/// SectionCard(
///   section: HelpSection(
///     title: 'Getting Started',
///     steps: ['Step 1: Create account', 'Step 2: Complete profile'],
///   ),
/// )
/// ```
class SectionCard extends StatelessWidget {
  /// The help section to display
  final HelpSection section;

  const SectionCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...section.steps.map((s) => StepRow(text: s)),
        ],
      ),
    );
  }
}

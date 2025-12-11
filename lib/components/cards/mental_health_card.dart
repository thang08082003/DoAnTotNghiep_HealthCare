import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../../data/resources/gene/app_text_styles.dart';

/// Mental Health Assessment Type
enum MentalHealthAssessmentType { anxiety, depression }

/// Reusable Mental Health Assessment Card Component
///
/// Supports both Anxiety (GAD-7) and Depression (PHQ-9) assessments
/// with color-coded severity levels and expandable recommendations
class MentalHealthCard extends StatelessWidget {
  final MentalHealthAssessmentType type;
  final int score;
  final int maxScore;
  final String levelDescription;
  final String recommendation;
  final DateTime createdAt;

  const MentalHealthCard({
    super.key,
    required this.type,
    required this.score,
    required this.maxScore,
    required this.levelDescription,
    required this.recommendation,
    required this.createdAt,
  });

  /// Factory constructor for Anxiety assessment (GAD-7)
  factory MentalHealthCard.anxiety({
    required int score,
    required String levelDescription,
    required String recommendation,
    required DateTime createdAt,
  }) {
    return MentalHealthCard(
      type: MentalHealthAssessmentType.anxiety,
      score: score,
      maxScore: 21,
      levelDescription: levelDescription,
      recommendation: recommendation,
      createdAt: createdAt,
    );
  }

  /// Factory constructor for Depression assessment (PHQ-9)
  factory MentalHealthCard.depression({
    required int score,
    required String levelDescription,
    required String recommendation,
    required DateTime createdAt,
  }) {
    return MentalHealthCard(
      type: MentalHealthAssessmentType.depression,
      score: score,
      maxScore: 27,
      levelDescription: levelDescription,
      recommendation: recommendation,
      createdAt: createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelData = _getLevelData();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _buildLeadingIcon(levelData),
        title: _buildTitle(levelData),
        subtitle: _buildSubtitle(),
        children: [_buildRecommendation()],
      ),
    );
  }

  Widget _buildLeadingIcon(_LevelData levelData) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: levelData.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(levelData.icon, color: levelData.color, size: 24),
    );
  }

  Widget _buildTitle(_LevelData levelData) {
    return Row(
      children: [
        Text('$score/$maxScore điểm', style: AppTextStyles.body1Bold),
        SizedBox(width: AppDimensions.spacingSmall),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: levelData.color.withValues(alpha: 0.1),
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          child: Text(
            levelDescription,
            style: TextStyle(
              color: levelData.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
      style: AppTextStyles.caption,
    );
  }

  Widget _buildRecommendation() {
    return Padding(
      padding: AppDimensions.paddingAllMedium,
      child: Container(
        padding: AppDimensions.paddingAllSmall,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: AppDimensions.borderRadiusMedium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(recommendation, style: AppTextStyles.body2)),
          ],
        ),
      ),
    );
  }

  _LevelData _getLevelData() {
    if (type == MentalHealthAssessmentType.anxiety) {
      return _getAnxietyLevelData();
    } else {
      return _getDepressionLevelData();
    }
  }

  _LevelData _getAnxietyLevelData() {
    // GAD-7 scoring: 0-21 points
    if (score <= 4) {
      return _LevelData(color: Colors.green, icon: Icons.sentiment_satisfied);
    } else if (score <= 9) {
      return _LevelData(color: Colors.orange, icon: Icons.sentiment_neutral);
    } else if (score <= 14) {
      return _LevelData(
        color: Colors.deepOrange,
        icon: Icons.sentiment_dissatisfied,
      );
    } else {
      return _LevelData(
        color: Colors.red,
        icon: Icons.sentiment_very_dissatisfied,
      );
    }
  }

  _LevelData _getDepressionLevelData() {
    // PHQ-9 scoring: 0-27 points
    if (score <= 4) {
      return _LevelData(color: Colors.green, icon: Icons.sentiment_satisfied);
    } else if (score <= 9) {
      return _LevelData(color: Colors.orange, icon: Icons.sentiment_neutral);
    } else if (score <= 14) {
      return _LevelData(
        color: Colors.deepOrange,
        icon: Icons.sentiment_dissatisfied,
      );
    } else if (score <= 19) {
      return _LevelData(
        color: Colors.red,
        icon: Icons.sentiment_very_dissatisfied,
      );
    } else {
      return _LevelData(
        color: Colors.red.shade900,
        icon: Icons.sentiment_very_dissatisfied,
      );
    }
  }
}

/// Internal data class for level styling
class _LevelData {
  final Color color;
  final IconData icon;

  _LevelData({required this.color, required this.icon});
}

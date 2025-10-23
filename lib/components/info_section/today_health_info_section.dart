import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/health_metrics_providers.dart';
import '../../screens/metrics/heart_rate_detail_screen.dart';
import '../../screens/metrics/spo2_detail_screen.dart';
import '../../screens/metrics/sleep_detail_screen.dart';
import '../../screens/metrics/hrv_detail_screen.dart';

class TodayHealthInfoSection extends ConsumerWidget {
  final String? userId;
  const TodayHealthInfoSection({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final String? effectiveUserId = userId ?? user?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông tin sức khỏe',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (effectiveUserId != null)
          _MetricsFromFirestore(
            displayUserId: effectiveUserId,
            navigateUserId: userId,
          ),
      ],
    );
  }
}

// removed _LazySpo2Detail; navigate with userId directly

// removed _LazySleepDetail; navigate with userId directly

String _fmtBpm(double? v) =>
    v == null || v <= 0 ? '-' : '${v.toStringAsFixed(0)} bpm';
String _fmtMs(double? v) => v == null || v <= 0 ? '-' : v.toStringAsFixed(0);
String _fmtPct(double? v) =>
    v == null || v <= 0 ? '-' : '${v.toStringAsFixed(0)} %';
String _fmtDur(Duration? d) {
  if (d == null || d <= Duration.zero) return '-';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h <= 0) return '${m}m';
  return '${h}h ${m}m';
}

class _MetricsFromFirestore extends ConsumerWidget {
  final String displayUserId; // dùng để đọc stream từ Firestore
  final String?
  navigateUserId; // dùng để điều hướng: null => màn chi tiết dùng Health Connect
  const _MetricsFromFirestore({
    required this.displayUserId,
    required this.navigateUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hrAsync = ref.watch(heartRateStreamProvider(displayUserId));
    final spo2Async = ref.watch(spo2StreamProvider(displayUserId));
    final hrvAsync = ref.watch(hrvStreamProvider(displayUserId));
    final sleepAsync = ref.watch(sleepSessionsStreamProvider(displayUserId));

    // Combine latest values (simple strategy: each AsyncValue separately and rebuild when any changes)
    final hr = hrAsync.valueOrNull?.isNotEmpty == true
        ? hrAsync.value!.first.bpm
        : null;
    final spo2 = spo2Async.valueOrNull?.isNotEmpty == true
        ? spo2Async.value!.first.percentage
        : null;
    final hrvSample = hrvAsync.valueOrNull?.isNotEmpty == true
        ? hrvAsync.value!.first
        : null;
    final hrvVal = hrvSample?.score?.toDouble();
    Duration? lastSleepDur;
    if (sleepAsync.valueOrNull?.isNotEmpty == true) {
      // Consider most recent session starting within last 36h
      final sess = sleepAsync.value!.first;
      lastSleepDur = Duration(minutes: sess.durationMinutes);
    }

    final hrText = _fmtBpm(hr);
    final hrvText = _fmtMs(hrvVal);
    final spo2Text = _fmtPct(spo2);
    final sleepText = _fmtDur(lastSleepDur);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        HeartRateDetailScreen(userId: navigateUserId),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: _buildMetricCard(
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.redAccent,
                  label: 'Nhịp tim',
                  value: hrText,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HrvDetailScreen(userId: navigateUserId),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: _buildMetricCard(
                  icon: Icons.show_chart,
                  iconColor: Colors.deepPurple,
                  label: 'HRV',
                  value: hrvText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Spo2DetailScreen(userId: navigateUserId),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: _buildMetricCard(
                  icon: Icons.bloodtype_rounded,
                  iconColor: Colors.teal,
                  label: 'SpO₂',
                  value: spo2Text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SleepDetailScreen(userId: navigateUserId),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: _buildMetricCard(
                  icon: Icons.nightlight_round,
                  iconColor: Colors.indigo,
                  label: 'Giấc ngủ',
                  value: sleepText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

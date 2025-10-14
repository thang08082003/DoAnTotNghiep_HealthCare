import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../doctors/doctors_following_list_screen.dart';
import '../metrics/heart_rate_detail_screen.dart';
import '../metrics/spo2_detail_screen.dart';
import '../metrics/sleep_detail_screen.dart';
import '../metrics/hrv_detail_screen.dart';
import '../../providers/health_metrics_providers.dart';

class PatientDashboardContent extends ConsumerWidget {
  const PatientDashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 360;
    // Quick access uses single cards now; no dynamic height needed
    final double welcomePad = isNarrow ? 20 : 26;
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (user) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Welcome card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(welcomePad),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.waving_hand,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, ${user?.name ?? 'Bạn'}!',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Chúc bạn có một ngày tốt lành',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
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
              const SizedBox(height: 24),

              const Text(
                'Thông tin sức khỏe hôm nay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (user != null) _MetricsFromFirestore(userId: user.uid),

              const SizedBox(height: 24),

              const Text(
                'Cảnh báo gần nhất từ AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildAiAlertCard(
                title: 'Nhịp tim tăng cao bất thường',
                description:
                    'AI phát hiện nhịp tim tăng cao trong 5 phút gần đây. Hãy nghỉ ngơi và theo dõi thêm.',
                timeLabel: '5 phút trước',
                levelColor: Colors.orange,
                icon: Icons.warning_amber_rounded,
              ),

              const SizedBox(height: 24),

              const Text(
                'Truy cập',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickAccessCard(
                icon: Icons.health_and_safety,
                title: 'Phát hiện sớm',
                subtitle: 'Rủi ro sức khỏe',
                color: Colors.green.withValues(alpha: 0.08),
                iconColor: Colors.green,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildQuickAccessCard(
                icon: Icons.chat_bubble_outline,
                title: 'Trao đổi với bác sĩ',
                subtitle: 'Nhắn tin & phản hồi',
                color: AppColors.primaryColor.withValues(alpha: 0.08),
                iconColor: AppColors.primaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DoctorsFollowingListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiAlertCard({
    required String title,
    required String description,
    required String timeLabel,
    required Color levelColor,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: levelColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nhịp tim tăng cao bất thường',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
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

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          // Compact mode when tiles are short, to avoid vertical overflow
          final compact = h < 80;
          final ultraCompact = h < 66;
          final pad = ultraCompact ? 8.0 : (compact ? 10.0 : 16.0);
          final iconSize = ultraCompact ? 16.0 : (compact ? 18.0 : 22.0);
          final gap1 = ultraCompact ? 4.0 : (compact ? 6.0 : 8.0);
          final gap2 = compact ? 2.0 : 4.0;
          final titleStyle = TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: ultraCompact ? 12 : (compact ? 13 : 14),
            height: ultraCompact ? 1.1 : (compact ? 1.15 : 1.2),
            color: AppColors.textPrimary,
          );
          final subtitleStyle = TextStyle(
            fontSize: compact ? 11 : 12,
            height: compact ? 1.1 : 1.2,
            color: AppColors.textSecondary,
          );

          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: iconSize),
                SizedBox(height: gap1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (!ultraCompact) ...[
                  SizedBox(height: gap2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Lazy wrapper to navigate to the detail screen
class _LazyHeartRateDetail extends StatelessWidget {
  const _LazyHeartRateDetail();
  @override
  Widget build(BuildContext context) => const HeartRateDetailScreen();
}

class _LazySpo2Detail extends StatelessWidget {
  const _LazySpo2Detail();
  @override
  Widget build(BuildContext context) => const Spo2DetailScreen();
}

class _LazySleepDetail extends StatelessWidget {
  const _LazySleepDetail();
  @override
  Widget build(BuildContext context) => const SleepDetailScreen();
}

String _fmtBpm(double? v) =>
    v == null || v <= 0 ? '-' : '${v.toStringAsFixed(0)} bpm';
String _fmtMs(double? v) =>
    v == null || v <= 0 ? '-' : '${v.toStringAsFixed(0)} ms';
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
  final String userId;
  const _MetricsFromFirestore({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hrAsync = ref.watch(heartRateStreamProvider(userId));
    final spo2Async = ref.watch(spo2StreamProvider(userId));
    final hrvAsync = ref.watch(hrvStreamProvider(userId));
    final sleepAsync = ref.watch(sleepSessionsStreamProvider(userId));

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
    final hrvVal = hrvSample?.sdnn ?? hrvSample?.rmssd;
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
                    builder: (_) => const _LazyHeartRateDetail(),
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
                  MaterialPageRoute(builder: (_) => const HrvDetailScreen()),
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
                  MaterialPageRoute(builder: (_) => const _LazySpo2Detail()),
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
                  MaterialPageRoute(builder: (_) => const _LazySleepDetail()),
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

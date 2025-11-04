import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/models/help_guide_model.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/providers/user_provider.dart';
import 'package:healthcare/viewmodels/help/help_view_model.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trợ giúp')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(message: 'Lỗi tải người dùng: $e'),
        data: (user) {
          if (user == null) {
            return const _Error(message: 'Không tìm thấy người dùng.');
          }
          final role = user.role;
          final state = ref.watch(helpViewModelProvider(role));
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return _Error(message: state.error!);
          }
          final guide = state.guide;
          if (guide == null) {
            return const _Error(message: 'Không có nội dung trợ giúp.');
          }
          return _GuideView(guide: guide);
        },
      ),
    );
  }
}

class _GuideView extends StatelessWidget {
  final HelpGuide guide;
  const _GuideView({required this.guide});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              guide.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }
        final section = guide.sections[index - 1];
        return _SectionCard(section: section);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: guide.sections.length + 1,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final HelpSection section;
  const _SectionCard({required this.section});

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
          ...section.steps.map((s) => _StepRow(text: s)).toList(),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String text;
  const _StepRow({required this.text});

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

class _Error extends StatelessWidget {
  final String message;
  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

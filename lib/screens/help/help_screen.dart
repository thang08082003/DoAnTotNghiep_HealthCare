import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/models/help_guide_model.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/providers/user_provider.dart';
import 'package:healthcare/viewmodels/help/help_view_model.dart';
import '../../components/info_section/section_card.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trợ giúp'), centerTitle: true),
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
        return SectionCard(section: section);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: guide.sections.length + 1,
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

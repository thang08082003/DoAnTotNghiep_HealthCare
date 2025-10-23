import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/user/user_avatar_view_model.dart';

class InlineUserAvatar extends ConsumerStatefulWidget {
  final String userId;
  final String? initialUrl;
  final String displayName;
  const InlineUserAvatar({
    super.key,
    required this.userId,
    required this.initialUrl,
    required this.displayName,
  });

  @override
  ConsumerState<InlineUserAvatar> createState() => _InlineUserAvatarState();
}

class _InlineUserAvatarState extends ConsumerState<InlineUserAvatar> {
  String? _url;
  bool _fetching = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
    if (_url == null || _url!.isEmpty) _fetch();
  }

  Future<void> _fetch() async {
    if (_tried) return;
    _tried = true;
    setState(() => _fetching = true);
    try {
      final vm = ref.read(userAvatarViewModelProvider);
      final url = await vm.getAvatarUrl(widget.userId);
      if (!mounted) return;
      setState(() => _url = url);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _url != null && _url!.isNotEmpty;
    final initials = _initials(widget.displayName);
    if (_fetching && !hasUrl) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        color: Colors.grey.withValues(alpha: 0.15),
        child: hasUrl
            ? Image.network(
                _url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(initials),
              )
            : _fallback(initials),
      ),
    );
  }

  Widget _fallback(String initials) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    ),
  );

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

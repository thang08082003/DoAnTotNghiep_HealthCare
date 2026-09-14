import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/user/user_avatar_view_model.dart';

class InlineUserAvatar extends ConsumerStatefulWidget {
  final String userId;
  final String? initialUrl;
  final String displayName;
  final double radius; // Customizable size
  const InlineUserAvatar({
    super.key,
    required this.userId,
    required this.initialUrl,
    required this.displayName,
    this.radius = 20, // Default 40x40 (radius * 2)
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
    if (_fetching && !hasUrl) {
      return SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: Center(
          child: SizedBox(
            width: widget.radius * 0.8,
            height: widget.radius * 0.8,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
      backgroundImage: hasUrl ? NetworkImage(_url!) : null,
      child: !hasUrl
          ? Icon(
              Icons.person,
              size: widget.radius * 1.2,
              color: AppColors.primaryColor,
            )
          : null,
    );
  }
}

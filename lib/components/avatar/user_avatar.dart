import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/profile/avatar_view_model.dart';
import '../../providers/user_provider.dart';

/// Avatar Size Presets
enum AvatarSize {
  small(20),
  medium(40),
  large(60),
  xlarge(80);

  final double radius;
  const AvatarSize(this.radius);
}

/// User Avatar Widget
///
/// Displays user avatar with automatic fallback to initials
/// Supports network images with loading and error states
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final double? radius;
  final AvatarSize? size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.displayName,
    this.radius,
    this.size,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  }) : assert(
         radius != null || size != null,
         'Either radius or size must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? size?.radius ?? AvatarSize.medium.radius;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final initials = _getInitials(displayName);

    final avatar = CircleAvatar(
      radius: effectiveRadius,
      backgroundColor:
          backgroundColor ?? AppColors.primaryColor.withValues(alpha: 0.1),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: !hasImage
          ? Text(
              initials,
              style: TextStyle(
                fontSize: effectiveRadius * 0.5,
                fontWeight: FontWeight.bold,
                color: foregroundColor ?? AppColors.primaryColor,
              ),
            )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';

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

/// Avatar with Network Image and Loading State
///
/// Shows loading indicator while fetching image
/// Automatically falls back to initials on error
class NetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double? radius;
  final AvatarSize? size;
  final BoxFit fit;

  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.radius,
    this.size,
    this.fit = BoxFit.cover,
  }) : assert(
         radius != null || size != null,
         'Either radius or size must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? size?.radius ?? AvatarSize.medium.radius;
    final dimension = effectiveRadius * 2;
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    final initials = _getInitials(displayName);

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: Container(
        width: dimension,
        height: dimension,
        color: Colors.grey.withValues(alpha: 0.15),
        child: hasUrl
            ? Image.network(
                imageUrl!,
                fit: fit,
                errorBuilder: (_, __, ___) => _FallbackContent(initials),
                loadingBuilder: (c, w, progress) {
                  if (progress == null) return w;
                  return Center(
                    child: SizedBox(
                      width: effectiveRadius * 0.4,
                      height: effectiveRadius * 0.4,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : _FallbackContent(initials),
      ),
    );
  }

  String _getInitials(String name) {
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

/// Fallback Content for Avatar
class _FallbackContent extends StatelessWidget {
  final String initials;

  const _FallbackContent(this.initials);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Avatar with Lazy Loading from User Repository
///
/// Fetches avatar URL from repository if not provided initially
/// Useful for displaying user avatars when only userId is known
class LazyLoadAvatar extends ConsumerStatefulWidget {
  final String userId;
  final String? initialUrl;
  final String displayName;
  final double? radius;
  final AvatarSize? size;

  const LazyLoadAvatar({
    super.key,
    required this.userId,
    this.initialUrl,
    required this.displayName,
    this.radius,
    this.size,
  }) : assert(
         radius != null || size != null,
         'Either radius or size must be provided',
       );

  @override
  ConsumerState<LazyLoadAvatar> createState() => _LazyLoadAvatarState();
}

class _LazyLoadAvatarState extends ConsumerState<LazyLoadAvatar> {
  String? _url;
  bool _loading = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
    if (_url == null || _url!.isEmpty) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_tried) return;
    _tried = true;
    setState(() => _loading = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _url = user?.avatarUrl;
      });
    } catch (_) {
      // Silently fail - will show initials
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        widget.radius ?? widget.size?.radius ?? AvatarSize.medium.radius;
    final dimension = effectiveRadius * 2;

    if (_loading && (_url == null || _url!.isEmpty)) {
      return SizedBox(
        width: dimension,
        height: dimension,
        child: Center(
          child: SizedBox(
            width: effectiveRadius * 0.4,
            height: effectiveRadius * 0.4,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return NetworkAvatar(
      imageUrl: _url,
      displayName: widget.displayName,
      radius: effectiveRadius,
    );
  }
}

/// Editable Avatar Picker
///
/// Allows user to pick and upload a new avatar image
/// Shows upload progress and handles errors
class AvatarPicker extends ConsumerStatefulWidget {
  final String? avatarUrl;
  final String userId;
  final VoidCallback onUpdated;
  final double? radius;
  final AvatarSize? size;

  const AvatarPicker({
    super.key,
    this.avatarUrl,
    required this.userId,
    required this.onUpdated,
    this.radius,
    this.size,
  }) : assert(
         radius != null || size != null,
         'Either radius or size must be provided',
       );

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _uploading = false;
  String? _overrideUrl;

  Future<void> _pickAndUpload() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final ext = picked.name.split('.').last.toLowerCase();
      final bytes = await picked.readAsBytes();

      final vm = ref.read(avatarViewModelProvider);
      final url = await vm.uploadAndSetAvatar(
        uid: widget.userId,
        bytes: bytes,
        fileExt: ext,
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          if (url != null) _overrideUrl = url;
        });
        if (url != null) {
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ảnh đại diện đã được cập nhật')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật ảnh: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        widget.radius ?? widget.size?.radius ?? AvatarSize.medium.radius;
    final effectiveUrl = _overrideUrl ?? widget.avatarUrl;
    final hasAvatar = (effectiveUrl != null && effectiveUrl.isNotEmpty);

    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: effectiveRadius,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            backgroundImage: hasAvatar
                ? NetworkImage(
                    '$effectiveUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                  )
                : null,
            child: !hasAvatar
                ? Icon(
                    Icons.person,
                    size: effectiveRadius,
                    color: AppColors.primaryColor,
                  )
                : null,
          ),
          if (_uploading)
            CircleAvatar(
              radius: effectiveRadius,
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: effectiveRadius * 0.4,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

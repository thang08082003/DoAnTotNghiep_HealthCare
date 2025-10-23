import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

class ChatAppBarTitle extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const ChatAppBarTitle({super.key, required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
          child: !hasAvatar
              ? const Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.primaryColor,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

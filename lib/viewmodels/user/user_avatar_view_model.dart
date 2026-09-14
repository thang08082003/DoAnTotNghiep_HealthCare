import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/user_repository.dart';

class UserAvatarViewModel {
  final UserRepository _repo = UserRepository();

  Future<String?> getAvatarUrl(String userId) async {
    final user = await _repo.getUserById(userId);
    return user?.avatarUrl;
  }
}

final userAvatarViewModelProvider = Provider<UserAvatarViewModel>((ref) {
  return UserAvatarViewModel();
});

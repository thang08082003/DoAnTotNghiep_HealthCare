import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/avatar_repository.dart';

class AvatarState {
  final bool uploading;
  final String? error;
  final String? lastUrl;
  const AvatarState({
    required this.uploading,
    required this.error,
    required this.lastUrl,
  });
  const AvatarState.initial() : uploading = false, error = null, lastUrl = null;
  AvatarState copyWith({bool? uploading, String? error, String? lastUrl}) {
    return AvatarState(
      uploading: uploading ?? this.uploading,
      error: error,
      lastUrl: lastUrl ?? this.lastUrl,
    );
  }
}

class AvatarViewModel extends StateNotifier<AvatarState> {
  final AvatarRepository _repo;
  AvatarViewModel(this._repo) : super(const AvatarState.initial());

  Future<String?> uploadAndSetAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    state = state.copyWith(uploading: true, error: null);
    try {
      final url = await _repo.uploadAvatarAndSave(
        uid: uid,
        bytes: bytes,
        fileExt: fileExt,
      );
      state = state.copyWith(uploading: false, lastUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(uploading: false, error: e.toString());
      return null;
    }
  }
}

final avatarViewModelProvider = Provider<AvatarViewModel>((ref) {
  return AvatarViewModel(AvatarRepository());
});

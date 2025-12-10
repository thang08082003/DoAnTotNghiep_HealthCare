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

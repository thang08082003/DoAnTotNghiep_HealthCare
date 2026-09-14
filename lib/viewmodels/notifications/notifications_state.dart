import '../../data/models/notification_model.dart';

class NotificationsState {
  final bool loading;
  final String? error;
  final List<AppNotification> items;

  const NotificationsState({
    required this.loading,
    required this.error,
    required this.items,
  });

  const NotificationsState.initial()
    : loading = true,
      error = null,
      items = const [];

  NotificationsState copyWith({
    bool? loading,
    String? error,
    List<AppNotification>? items,
  }) {
    return NotificationsState(
      loading: loading ?? this.loading,
      error: error,
      items: items ?? this.items,
    );
  }
}

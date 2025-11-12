import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/follow_request_repository.dart';

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

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  final FollowRequestRepository _followRepo;
  StreamSubscription<List<AppNotification>>? _sub;

  NotificationsViewModel(this._repo, this._followRepo)
    : super(const NotificationsState.initial());

  void start(String userId) {
    _sub?.cancel();
    state = state.copyWith(loading: true, error: null);
    _sub = _repo
        .watchUserNotifications(userId)
        .listen(
          (items) {
            state = state.copyWith(loading: false, error: null, items: items);
          },
          onError: (e) {
            state = state.copyWith(loading: false, error: e.toString());
          },
        );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    state = const NotificationsState.initial();
  }

  Future<void> markAsRead(String id) => _repo.markAsRead(id);
  Future<void> delete(String id) => _repo.deleteNotification(id);

  Future<void> acceptFollow({
    required String requestId,
    required String doctorId,
    required String patientId,
  }) async {
    await _followRepo.acceptRequest(
      requestId: requestId,
      doctorId: doctorId,
      patientId: patientId,
    );
  }

  Future<void> declineFollow({
    required String requestId,
    required String doctorId,
    required String patientId,
  }) async {
    await _followRepo.declineRequest(
      requestId: requestId,
      doctorId: doctorId,
      patientId: patientId,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notificationsViewModelProvider =
    StateNotifierProvider.family<
      NotificationsViewModel,
      NotificationsState,
      String
    >((ref, userId) {
      final vm = NotificationsViewModel(
        NotificationRepository(),
        FollowRequestRepository(),
      );
      if (userId.isNotEmpty) {
        vm.start(userId);
      }
      return vm;
    });

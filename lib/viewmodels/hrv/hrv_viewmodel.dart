import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../providers/metrics_di_providers.dart';
import '../../providers/user_provider.dart';

typedef UserId = String?;

final hrvViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<HrvViewModel, HrvAggregate, UserId>(
      HrvViewModel.new,
    );

class HrvViewModel
    extends AutoDisposeFamilyAsyncNotifier<HrvAggregate, UserId> {
  @override
  Future<HrvAggregate> build(UserId arg) async {
    final usecase = ref.read(metricsUsecaseProvider);
    // HRV requires a concrete user id; if not provided, fallback to current user
    String? uid = arg;
    if (uid == null) {
      final user = await ref.read(currentUserProvider.future);
      uid = user?.uid;
    }
    if (uid == null) {
      // When user is not available, return an empty structure
      return HrvAggregate(
        dayHourlyScore: [],
        dayRmssd: const StatsAgg(),
        weekScoreAvg: [],
        monthScoreAvg: [],
        weekStart: DateTime.fromMillisecondsSinceEpoch(0),
        weekPnn50: [],
        weekHr: [],
        weekScore: [],
        weekSdnn: [],
        monthPnn50: [],
        monthHr: [],
        monthScore: [],
        monthSdnn: [],
      );
    }
    return usecase.hrv(userId: uid);
  }

  Future<void> refresh() async {
    final arg = this.arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final usecase = ref.read(metricsUsecaseProvider);
      String? uid = arg;
      if (uid == null) {
        final user = await ref.read(currentUserProvider.future);
        uid = user?.uid;
      }
      if (uid == null) {
        return HrvAggregate(
          dayHourlyScore: [],
          dayRmssd: const StatsAgg(),
          weekScoreAvg: [],
          monthScoreAvg: [],
          weekStart: DateTime.fromMillisecondsSinceEpoch(0),
          weekPnn50: [],
          weekHr: [],
          weekScore: [],
          weekSdnn: [],
          monthPnn50: [],
          monthHr: [],
          monthScore: [],
          monthSdnn: [],
        );
      }
      return usecase.hrv(userId: uid);
    });
  }
}

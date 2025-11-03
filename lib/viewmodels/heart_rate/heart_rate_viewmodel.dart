import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../data/domain/metrics_usecase.dart';

typedef UserId = String?;

final heartRateViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      HeartRateViewModel,
      MetricAggregate,
      UserId
    >(HeartRateViewModel.new);

class HeartRateViewModel
    extends AutoDisposeFamilyAsyncNotifier<MetricAggregate, UserId> {
  @override
  Future<MetricAggregate> build(UserId arg) async {
    final usecase = ref.read(metricsUsecaseProvider);
    return usecase.heartRate(userId: arg);
  }

  Future<void> refresh() async {
    final arg = this.arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final usecase = ref.read(metricsUsecaseProvider);
      return usecase.heartRate(userId: arg);
    });
  }
}

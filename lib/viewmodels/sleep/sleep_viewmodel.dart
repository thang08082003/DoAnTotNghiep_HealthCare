import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../providers/metrics_di_providers.dart';

typedef UserId = String?;

final sleepViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      SleepViewModel,
      SleepAggregate,
      UserId
    >(SleepViewModel.new);

class SleepViewModel
    extends AutoDisposeFamilyAsyncNotifier<SleepAggregate, UserId> {
  @override
  Future<SleepAggregate> build(UserId arg) async {
    final usecase = ref.read(metricsUsecaseProvider);
    return usecase.sleep(userId: arg);
  }

  Future<void> refresh() async {
    final arg = this.arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final usecase = ref.read(metricsUsecaseProvider);
      return usecase.sleep(userId: arg);
    });
  }
}

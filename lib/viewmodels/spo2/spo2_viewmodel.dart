import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../providers/metrics_di_providers.dart';

// userId is now required (non-nullable) - all data comes from Firestore
typedef UserId = String;

final spo2ViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      Spo2ViewModel,
      MetricAggregate,
      UserId
    >(Spo2ViewModel.new);

class Spo2ViewModel
    extends AutoDisposeFamilyAsyncNotifier<MetricAggregate, UserId> {
  @override
  Future<MetricAggregate> build(UserId userId) async {
    final usecase = ref.read(metricsUsecaseProvider);
    return usecase.spo2(userId: userId);
  }

  Future<void> refresh() async {
    final userId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final usecase = ref.read(metricsUsecaseProvider);
      return usecase.spo2(userId: userId);
    });
  }
}

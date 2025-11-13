import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/health_connect_service.dart';
import 'package:health/health.dart';

/// ViewModel to orchestrate Health Connect sync and notify consumers
class HealthConnectViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  HealthConnectViewModel(this.ref) : super(const AsyncData(null));

  // Lightweight DTO for latest metrics snapshot
  ({
    double? hr,
    DateTime? hrTime,
    double? spo2,
    DateTime? spo2Time,
    Duration? lastNightSleep,
  })
  _Latest(
    double? hr,
    DateTime? hrTime,
    double? spo2,
    DateTime? spo2Time,
    Duration? sleep,
  ) => (
    hr: hr,
    hrTime: hrTime,
    spo2: spo2,
    spo2Time: spo2Time,
    lastNightSleep: sleep,
  );

  /// Fetch latest HR, SpO2 within last 24h and last night's sleep duration
  Future<
    ({
      double? hr,
      DateTime? hrTime,
      double? spo2,
      DateTime? spo2Time,
      Duration? lastNightSleep,
    })
  >
  fetchLatestMetrics() async {
    final svc = GoogleFitService();
    try {
      await svc.ensureConnected();
    } catch (_) {}

    double? latestHr;
    DateTime? latestHrTime;
    double? latestSpo2;
    DateTime? latestSpo2Time;
    Duration? lastNightSleep;

    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(days: 1));

    // HR
    try {
      final hr = await svc.getData(
        types: const [HealthDataType.HEART_RATE],
        start: dayAgo,
        end: now,
      );
      if (hr.isNotEmpty) {
        hr.sort((a, b) {
          final aa = a.dateTo.isAfter(a.dateFrom) ? a.dateTo : a.dateFrom;
          final bb = b.dateTo.isAfter(b.dateFrom) ? b.dateTo : b.dateFrom;
          return aa.compareTo(bb);
        });
        for (final p in hr.reversed) {
          final v = p.value;
          if (v is NumericHealthValue) {
            final bpm = v.numericValue.toDouble();
            if (bpm > 0) {
              latestHr = bpm;
              latestHrTime = p.dateTo.isAfter(p.dateFrom)
                  ? p.dateTo
                  : p.dateFrom;
              break;
            }
          }
        }
      }
    } catch (_) {}

    // SpO2
    try {
      final spo2 = await svc.getData(
        types: const [HealthDataType.BLOOD_OXYGEN],
        start: dayAgo,
        end: now,
      );
      if (spo2.isNotEmpty) {
        spo2.sort((a, b) {
          final aa = a.dateTo.isAfter(a.dateFrom) ? a.dateTo : a.dateFrom;
          final bb = b.dateTo.isAfter(b.dateFrom) ? b.dateTo : b.dateFrom;
          return aa.compareTo(bb);
        });
        for (final p in spo2.reversed) {
          final v = p.value;
          if (v is NumericHealthValue) {
            final pct = v.numericValue.toDouble();
            if (pct > 0) {
              latestSpo2 = pct;
              latestSpo2Time = p.dateTo.isAfter(p.dateFrom)
                  ? p.dateTo
                  : p.dateFrom;
              break;
            }
          }
        }
      }
    } catch (_) {}

    // Sleep last night
    try {
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      Duration total = Duration.zero;
      var sleep = await svc.getData(
        types: const [HealthDataType.SLEEP_SESSION],
        start: yesterday,
        end: today,
      );
      if (sleep.isEmpty) {
        sleep = await svc.getData(
          types: const [HealthDataType.SLEEP_ASLEEP],
          start: yesterday,
          end: today,
        );
      }
      for (final s in sleep) {
        final dt = s.dateTo.difference(s.dateFrom);
        if (!dt.isNegative) total += dt;
      }
      if (total > Duration.zero) {
        lastNightSleep = total;
      }
    } catch (_) {}

    return _Latest(
      latestHr,
      latestHrTime,
      latestSpo2,
      latestSpo2Time,
      lastNightSleep,
    );
  }

  /// Dump Health Connect data logs for troubleshooting
  Future<void> dumpHealthLog({int days = 7}) async {
    final svc = GoogleFitService();
    try {
      await svc.ensureConnected();
    } catch (_) {}
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    // ignore: avoid_print
    print(
      '===== Health Connect dump ${start.toIso8601String()} -> ${now.toIso8601String()} =====',
    );
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ];
    for (final t in types) {
      try {
        final data = await svc.getData(types: [t], start: start, end: now);
        data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        // ignore: avoid_print
        print('-- ${t.name}: count=${data.length}');
        if (data.isEmpty) continue;
        final first = data.first.dateFrom.toIso8601String();
        final last =
            (data.last.dateTo.isAfter(data.last.dateFrom)
                    ? data.last.dateTo
                    : data.last.dateFrom)
                .toIso8601String();
        // ignore: avoid_print
        print('   range: first=$first last=$last');
        for (final p in data) {
          final from = p.dateFrom.toIso8601String();
          final to = p.dateTo.toIso8601String();
          final v = p.value;
          String valStr;
          if (v is NumericHealthValue) {
            valStr = v.numericValue.toString();
          } else {
            valStr = v.toString();
          }
          // ignore: avoid_print
          print('   [${t.name}] $from -> $to | value=$valStr');
        }
      } catch (e) {
        // ignore: avoid_print
        print('-- ${t.name}: error $e');
      }
    }
  }
}

final healthConnectViewModelProvider =
    StateNotifierProvider.autoDispose<HealthConnectViewModel, AsyncValue<void>>(
      (ref) {
        return HealthConnectViewModel(ref);
      },
    );

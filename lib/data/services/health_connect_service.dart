import 'dart:async';
import 'package:health/health.dart';
// No explicit Google Sign-In needed for Health Connect reads; the health plugin handles auth.
import 'package:permission_handler/permission_handler.dart';

class GoogleFitService {
  // Health API entry
  final Health _health = Health();

  // Ask for Android runtime permissions that complement Health Connect
  Future<bool> _ensureRuntimePermissions() async {
    // Request BODY_SENSORS and ACTIVITY_RECOGNITION if not already granted
    final toRequest = <Permission>[
      Permission.sensors, // BODY_SENSORS
      Permission.activityRecognition, // ACTIVITY_RECOGNITION
    ];

    // Optional: request notifications (not required for Health Connect)
    // if (await Permission.notification.isDenied) {
    //   toRequest.add(Permission.notification);
    // }

    final statuses = await toRequest.request();

    // Check critical ones
    final sensorsOk = statuses[Permission.sensors]?.isGranted ?? false;
    final activityOk =
        statuses[Permission.activityRecognition]?.isGranted ?? false;

    // If either is permanently denied, suggest opening app settings
    final sensorsPermanently =
        statuses[Permission.sensors]?.isPermanentlyDenied ?? false;
    final activityPermanently =
        statuses[Permission.activityRecognition]?.isPermanentlyDenied ?? false;
    if (sensorsPermanently || activityPermanently) {
      // Best effort: open settings; caller can show guidance UI as needed
      // ignore: unawaited_futures
      openAppSettings();
    }

    return sensorsOk && activityOk;
  }

  Future<bool> ensureConnected() async {
    // Prefer Health Connect only: verify availability first
    try {
      final status = await _health.getHealthConnectSdkStatus();
      final s = status.toString().toLowerCase();
      if (s.contains('notSupported'.toLowerCase())) {
        throw StateError('Thiết bị không hỗ trợ Health Connect');
      }
      if (s.contains('notInstalled'.toLowerCase())) {
        // Trên Android 13 trở xuống cần cài app Health Connect
        throw StateError('Chưa cài ứng dụng Health Connect');
      }
    } catch (_) {
      // Nếu phương thức không khả dụng do phiên bản plugin, tiếp tục xin quyền
    }

    // Ensure plugin is configured as recommended by the health package
    try {
      await _health.configure();
    } catch (_) {}

    // Best-effort: request Android runtime permissions (not strictly required for Health Connect reads)
    // Do not block if user denies; Health Connect authorization may still succeed.
    try {
      await _ensureRuntimePermissions();
    } catch (_) {}

    // Request Health permissions so the OS dialog can appear (HC on Android 14+ or Health Connect app on <=13)
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,

      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      // Detailed sleep stages when available
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ];
    // Newer health API can infer read access; if permissions param isn't supported, ignore.
    bool granted = false;
    try {
      // Try with explicit permissions if available
      final permissions = types.map((_) => HealthDataAccess.READ).toList();
      granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
    } catch (_) {
      // Fallback older signature
      granted = await _health.requestAuthorization(types);
    }

    // If granted, also check and request access to historical data beyond the default 30 days window
    if (granted) {
      try {
        final hasHistory = await _health.isHealthDataHistoryAuthorized();
        if (hasHistory == false) {
          await _health.requestHealthDataHistoryAuthorization();
        }
      } catch (_) {
        // Method may not be available on older plugin versions
      }
    }
    return granted;
  }

  /// Diagnostics helper to understand device Health Connect status and permission state.
  Future<HealthDebugInfo> diagnose() async {
    String sdkStatus = 'unknown';
    try {
      final status = await _health.getHealthConnectSdkStatus();
      sdkStatus = status.toString();
    } catch (_) {
      sdkStatus = 'unavailable (method not supported by this plugin version)';
    }

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
    bool hasPerms = false;
    try {
      final permissions = types.map((_) => HealthDataAccess.READ).toList();
      hasPerms =
          await _health.hasPermissions(types, permissions: permissions) ??
          false;
    } catch (_) {
      try {
        hasPerms = await _health.hasPermissions(types) ?? false;
      } catch (_) {}
    }

    return HealthDebugInfo(sdkStatus: sdkStatus, hasPermissions: hasPerms);
  }

  Future<GoogleFitSummary> fetchSummary({
    Duration range = const Duration(days: 7),
  }) async {
    final ok = await ensureConnected();
    if (!ok) throw StateError('Không thể kết nối Health Connect');
    final end = DateTime.now();
    final start = end.subtract(range);

    double? avgHr;
    double? avgSpo2;
    Duration totalSleep = Duration.zero;

    // Heart rate
    try {
      final hr = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.HEART_RATE],
      );
      if (hr.isNotEmpty) {
        final values = hr
            .map((e) {
              final v = e.value;
              if (v is NumericHealthValue) {
                final num nv = v.numericValue;
                return nv.toDouble();
              }
              return null;
            })
            .whereType<double>()
            .where((v) => v > 0)
            .toList();
        if (values.isNotEmpty) {
          avgHr = values.reduce((a, b) => a + b) / values.length;
        }
      }
    } catch (_) {}

    // SpO2
    try {
      final spo2 = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.BLOOD_OXYGEN],
      );
      if (spo2.isNotEmpty) {
        final values = spo2
            .map((e) {
              final v = e.value;
              if (v is NumericHealthValue) {
                final num nv = v.numericValue;
                return nv.toDouble();
              }
              return null;
            })
            .whereType<double>()
            .where((v) => v > 0)
            .toList();
        if (values.isNotEmpty) {
          avgSpo2 = values.reduce((a, b) => a + b) / values.length;
        }
      }
    } catch (_) {}

    // Sleep blocks — prefer SLEEP_SESSION if available, otherwise sum SLEEP_ASLEEP durations
    try {
      // First try sessions
      List<HealthDataPoint> sleep = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.SLEEP_SESSION],
      );
      if (sleep.isEmpty) {
        // Fallback to asleep/awake blocks
        sleep = await _health.getHealthDataFromTypes(
          startTime: start,
          endTime: end,
          types: const [
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_AWAKE,
          ],
        );
        for (final s in sleep) {
          if (s.type == HealthDataType.SLEEP_ASLEEP) {
            final sdt = s.dateFrom;
            final edt = s.dateTo;
            if (edt.isAfter(sdt)) {
              totalSleep += edt.difference(sdt);
            }
          }
        }
      } else {
        for (final s in sleep) {
          final sdt = s.dateFrom;
          final edt = s.dateTo;
          if (edt.isAfter(sdt)) {
            totalSleep += edt.difference(sdt);
          }
        }
      }
    } catch (_) {}

    return GoogleFitSummary(
      averageHeartRate: avgHr,
      averageSpo2: avgSpo2,
      totalSleep: totalSleep,
    );
  }

  // Public helper to fetch raw data points after ensuring connection/permission
  Future<List<HealthDataPoint>> getData({
    required List<HealthDataType> types,
    required DateTime start,
    required DateTime end,
  }) async {
    final ok = await ensureConnected();
    if (!ok) throw StateError('Không thể kết nối Health Connect');
    return _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: types,
    );
  }

  // Fast path: assumes ensureConnected() was called by the caller; avoids
  // re-checking permissions for every small range to speed up batch queries.
  Future<List<HealthDataPoint>> getDataFast({
    required List<HealthDataType> types,
    required DateTime start,
    required DateTime end,
  }) async {
    return _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: types,
    );
  }
}

class GoogleFitSummary {
  final double? averageHeartRate;
  final double? averageSpo2; // 0-100
  final Duration totalSleep; // over the range

  const GoogleFitSummary({
    required this.averageHeartRate,
    required this.averageSpo2,
    required this.totalSleep,
  });
}

class HealthDebugInfo {
  final String
  sdkStatus; // e.g. HealthConnectSdkStatus.installed, notInstalled, notSupported
  final bool hasPermissions;

  const HealthDebugInfo({
    required this.sdkStatus,
    required this.hasPermissions,
  });
}

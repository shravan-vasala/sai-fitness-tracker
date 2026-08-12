import 'package:health/health.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repositories/daily_log_repository.dart';
import '../repositories/habit_repository.dart';

import '../models/feature_availability.dart';

enum StepsSource { healthConnect, manual, none }

class HealthConnectService {
  static const String _metaBoxName = 'health_connect_meta';
  static const String _backfillDoneKey = 'backfill_done';

  final Health _health = Health();
  late Box<String> _metaBox;
  bool _configured = false;

  Future<void> init() async {
    _metaBox = await Hive.openBox<String>(_metaBoxName);
  }

  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  Future<FeatureAvailability> getAvailability() async {
    if (!await isAvailable()) return FeatureAvailability.unavailable;
    if (!await isAuthorized()) return FeatureAvailability.disabled;
    return FeatureAvailability.available;
  }

  /// Check if Health Connect app is installed on the device.
  Future<bool> isAvailable() async {
    try {
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Check if we already have STEPS + SLEEP_SESSION read permission.
  Future<bool> isAuthorized() async {
    try {
      await _ensureConfigured();
      final types = [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION];
      final perms = [HealthDataAccess.READ, HealthDataAccess.READ];
      return await _health.hasPermissions(types, permissions: perms) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request STEPS + SLEEP_SESSION read permission from Health Connect.
  Future<bool> requestPermission() async {
    try {
      await _ensureConfigured();
      // Request activity recognition first (required for step data)
      await Permission.activityRecognition.request();
      
      final types = [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION];
      final perms = [HealthDataAccess.READ, HealthDataAccess.READ];
      return await _health.requestAuthorization(types, permissions: perms);
    } catch (_) {
      return false;
    }
  }

  /// Request historical data access (needed for >30 day backfill).
  Future<bool> requestHistoryAccess() async {
    try {
      await _ensureConfigured();
      return await _health.requestHealthDataHistoryAuthorization();
    } catch (_) {
      return false;
    }
  }

  /// Get today's total step count from Health Connect.
  Future<int?> getTodaySteps() async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// Get step count for a specific calendar day.
  Future<int?> getStepsForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// Get sleep hours for a specific calendar day.
  /// Health Connect often stores sleep sessions from previous night to current morning.
  Future<double?> getSleepForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      // Sleep for a date usually means sleep ending on that date
      final start = DateTime(date.year, date.month, date.day - 1, 18, 0); // 6 PM previous day
      final end = DateTime(date.year, date.month, date.day, 18, 0); // 6 PM current day
      
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: start,
        endTime: end,
      );
      
      if (healthData.isEmpty) return null;
      
      // Calculate total minutes of sleep
      double totalMinutes = 0;
      for (final data in healthData) {
        totalMinutes += data.dateTo.difference(data.dateFrom).inMinutes;
      }
      
      return double.parse((totalMinutes / 60).toStringAsFixed(1));
    } catch (_) {
      return null;
    }
  }

  /// Whether the 90-day backfill has already been done.
  bool get isBackfillDone => _metaBox.get(_backfillDoneKey) == 'true';

  /// Helper to update steps and handle habit auto-completion logic.
  Future<void> _syncStepValueAndHabit(
    String dateStr,
    int steps,
    DailyLogRepository dailyLogRepo,
    HabitRepository habitRepo,
    bool isToday,
  ) async {
    await dailyLogRepo.updateSteps(dateStr, steps, source: 'healthConnect');
  }

  Future<void> _syncSleepValue(
    String dateStr,
    double sleepHours,
    DailyLogRepository dailyLogRepo,
  ) async {
    await dailyLogRepo.updateSleep(dateStr, sleepHours, source: 'healthConnect');
  }

  /// Backfill the last 90 days of step data into Hive.
  /// Skips days that already have manually-entered steps.
  Future<int> backfillLast90Days(DailyLogRepository dailyLogRepo, HabitRepository habitRepo) async {
    if (isBackfillDone) return 0;

    final hasAuth = await isAuthorized();
    if (!hasAuth) {
      final granted = await requestPermission();
      if (!granted) return 0;
    }

    // Try to request history access for >30 days
    await requestHistoryAccess();

    int count = 0;
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final todayStr = dateFormat.format(now);

    for (int i = 1; i <= 90; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final existing = dailyLogRepo.getLog(dateStr);

      // Sync steps
      if (existing == null || existing.steps == null || existing.stepsSource != 'manual') {
        final steps = await getStepsForDate(date);
        if (steps != null && steps > 0) {
          await _syncStepValueAndHabit(dateStr, steps, dailyLogRepo, habitRepo, dateStr == todayStr);
          count++;
        }
      }

      // Sync sleep
      if (existing == null || existing.sleepHours == null || existing.sleepSource != 'manual') {
        final sleep = await getSleepForDate(date);
        if (sleep != null && sleep > 0) {
          await _syncSleepValue(dateStr, sleep, dailyLogRepo);
          count++;
        }
      }
    }

    await _metaBox.put(_backfillDoneKey, 'true');
    return count;
  }

  /// Re-read the last 7 days (Samsung Health revises recent totals).
  /// Does NOT overwrite manually-entered steps.
  Future<int> syncLast7Days(DailyLogRepository dailyLogRepo, HabitRepository habitRepo) async {
    int count = 0;
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final todayStr = dateFormat.format(now);

    for (int i = 0; i <= 6; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final existing = dailyLogRepo.getLog(dateStr);

      // Sync steps
      if (existing == null || existing.steps == null || existing.stepsSource != 'manual') {
        final steps = await getStepsForDate(date);
        if (steps != null && steps > 0) {
          await _syncStepValueAndHabit(dateStr, steps, dailyLogRepo, habitRepo, dateStr == todayStr);
          count++;
        }
      }

      // Sync sleep
      if (existing == null || existing.sleepHours == null || existing.sleepSource != 'manual') {
        final sleep = await getSleepForDate(date);
        if (sleep != null && sleep > 0) {
          await _syncSleepValue(dateStr, sleep, dailyLogRepo);
          count++;
        }
      }
    }

    return count;
  }

  /// Sync today's steps and auto-complete the walk habit if target met.
  Future<int?> syncTodayAndAutoCompleteHabit(
    DailyLogRepository dailyLogRepo,
    HabitRepository habitRepo,
  ) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final existing = dailyLogRepo.getLog(dateStr);

    // Sync sleep
    if (existing == null || existing.sleepHours == null || existing.sleepSource != 'manual') {
      final sleep = await getSleepForDate(now);
      if (sleep != null && sleep > 0) {
        await _syncSleepValue(dateStr, sleep, dailyLogRepo);
      }
    }

    // Don't overwrite manual entries for steps
    if (existing != null && existing.steps != null && existing.stepsSource == 'manual') {
      return existing.steps;
    }

    final steps = await getTodaySteps();
    // A successful HC read can be 0 (e.g. early morning) — still persist it.
    if (steps != null) {
      await _syncStepValueAndHabit(dateStr, steps, dailyLogRepo, habitRepo, true);
      return steps;
    }
    return existing?.steps;
  }

  /// Try reading today's steps to verify permission.
  /// [hasPermissions] is unreliable on Android Health Connect after process death.
  Future<bool> canReadSteps() async {
    try {
      final steps = await getTodaySteps();
      return steps != null;
    } catch (_) {
      return false;
    }
  }
}

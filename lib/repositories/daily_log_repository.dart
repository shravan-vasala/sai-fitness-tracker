import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/daily_log.dart';
import '../interfaces/i_cloud_sync_service.dart';

class DailyLogRepository {
  static const String _boxName = 'daily_logs_v2';

  late Box<DailyLog> _box;
  ICloudSyncService? _sync;

  /// Attach a Firestore sync service (called after sign-in).
  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _box = await Hive.openBox<DailyLog>(_boxName);
  }

  DailyLog? getLog(String date) {
    return _box.get(date);
  }

  DailyLog getOrCreate(String date) {
    return getLog(date) ?? DailyLog(date: date);
  }

  Future<void> saveLog(DailyLog log) async {
    await _box.put(log.date, log);
    _sync?.syncToCloud('daily_logs', log.date, log.toJson());
  }

  Future<void> updateWeight(String date, double weight) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(weight: weight));
  }

  Future<void> updateSteps(String date, int steps, {String? source}) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(steps: steps, stepsSource: source));
  }

  Future<void> updateScreenTime(String date, int minutes) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(screenTimeMinutes: minutes));
  }

  Future<void> updateSleep(String date, double? hours, {String? source}) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(
      sleepHours: hours,
      sleepSource: source,
    ));
  }

  Future<void> clearSleep(String date) async {
    final log = getOrCreate(date);
    await saveLog(log.clearSleep());
  }

  Future<void> updateBodyFat(String date, double bodyFat) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(bodyFat: bodyFat));
  }

  Future<void> markWorkoutCompleted(String date, String dayId) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(workoutCompleted: true, workoutDayId: dayId));
  }

  List<DailyLog> getLogsInRange(String startDate, String endDate) {
    final logs = <DailyLog>[];
    for (final key in _box.keys) {
      final dateKey = key as String;
      if (dateKey.compareTo(startDate) >= 0 && dateKey.compareTo(endDate) <= 0) {
        final log = getLog(dateKey);
        if (log != null) logs.add(log);
      }
    }
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  List<DailyLog> getAllLogs() {
    final logs = _box.values.toList();
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  bool hasActivityOnDate(String date) {
    final log = getLog(date);
    return log?.hasAnyActivity ?? false;
  }

  /// Bulk import from Firestore (used on new-device sign-in).
  Future<void> importFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      // Only import if local doesn't already have data for this date
      if (!_box.containsKey(entry.key)) {
        final log = DailyLog.fromJson(entry.value);
        await _box.put(entry.key, log);
      }
    }
  }

  /// Export all local data as a map for bulk cloud upload.
  Map<String, Map<String, dynamic>> exportForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final log in _box.values) {
      result[log.date] = log.toJson();
    }
    return result;
  }
}

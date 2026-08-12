import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../interfaces/i_cloud_sync_service.dart';

class ExerciseLogRepository {
  static const String _boxName = 'exercise_logs_v2';
  static const String _prBoxName = 'exercise_prs_v2';

  late Box<ExerciseLog> _box;
  late Box<ExercisePr> _prBox;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _box = await Hive.openBox<ExerciseLog>(_boxName);
    _prBox = await Hive.openBox<ExercisePr>(_prBoxName);
  }

  ExercisePr? getPr(String exerciseName) {
    return _prBox.get(exerciseName);
  }

  Future<void> savePr(ExercisePr pr) async {
    await _prBox.put(pr.exerciseName, pr);
    _sync?.syncToCloud('exercise_prs', pr.exerciseName, pr.toJson());
  }

  ExerciseLog? getLog(String date, String exerciseName) {
    final key = '${date}_$exerciseName';
    return _box.get(key);
  }

  Future<void> saveLog(ExerciseLog log) async {
    await _box.put(log.key, log);
    _sync?.syncToCloud('exercise_logs', log.key, log.toJson());
  }

  bool hasLog(String date, String exerciseName) {
    return _box.containsKey('${date}_$exerciseName');
  }

  List<ExerciseLog> getLogsForExercise(String exerciseName) {
    final logs = <ExerciseLog>[];
    for (final key in _box.keys) {
      final keyStr = key as String;
      if (keyStr.endsWith('_$exerciseName')) {
        final log = _box.get(keyStr);
        if (log != null) {
          logs.add(log);
        }
      }
    }
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  List<ExerciseLog> getLogsForDate(String date) {
    final logs = <ExerciseLog>[];
    for (final key in _box.keys) {
      final keyStr = key as String;
      if (keyStr.startsWith('${date}_')) {
        final log = _box.get(keyStr);
        if (log != null) {
          logs.add(log);
        }
      }
    }
    return logs;
  }

  // ── Cloud sync helpers ──

  Future<void> importLogsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_box.containsKey(entry.key)) {
        final log = ExerciseLog.fromJson(entry.value);
        await _box.put(entry.key, log);
      }
    }
  }

  Future<void> importPrsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_prBox.containsKey(entry.key)) {
        final pr = ExercisePr.fromJson(entry.value);
        await _prBox.put(entry.key, pr);
      }
    }
  }

  Map<String, Map<String, dynamic>> exportLogsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _box.keys) {
      final log = _box.get(key as String);
      if (log != null) result[key] = log.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportPrsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final pr in _prBox.values) {
      result[pr.exerciseName] = pr.toJson();
    }
    return result;
  }
}

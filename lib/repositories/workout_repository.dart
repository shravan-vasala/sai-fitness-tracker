import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/workout_plan.dart';
import '../interfaces/i_cloud_sync_service.dart';

class WorkoutRepository {
  static const String _planBoxName = 'workout_plans_v2';
  static const String _sessionBoxName = 'workout_sessions_v2';
  late Box<WorkoutPlan> _planBox;
  late Box<String> _sessionBox;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _planBox = await Hive.openBox<WorkoutPlan>(_planBoxName);
    _sessionBox = await Hive.openBox<String>(_sessionBoxName);
    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    if (_planBox.isEmpty) {
      final jsonStr = await rootBundle.loadString('assets/data/seed_workout_plan.json');
      final plan = WorkoutPlan.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      _planBox.put('beginner_plan', plan);

      final gymJsonStr = await rootBundle.loadString('assets/data/gym_split_plan.json');
      final gymPlan = WorkoutPlan.fromJson(jsonDecode(gymJsonStr) as Map<String, dynamic>);
      _planBox.put('gym_split_plan', gymPlan);
    }
  }

  List<WorkoutPlan> getAllPlans() {
    return _planBox.values.toList();
  }

  WorkoutPlan? getPlan(String key) {
    return _planBox.get(key);
  }

  /// Resolves the plan for [preferredKey], falling back to `gym_split_plan`
  /// then the first stored plan (same pattern as meal plans).
  WorkoutPlan? getActivePlan({String? preferredKey}) {
    if (_planBox.isEmpty) return null;
    if (preferredKey != null) {
      final preferred = getPlan(preferredKey);
      if (preferred != null) return preferred;
    }
    return getPlan('gym_split_plan') ??
        getPlan(_planBox.keys.first as String);
  }

  WorkoutDay? getWorkoutDay(String dayId) {
    final plans = getAllPlans();
    for (final plan in plans) {
      for (final day in plan.days) {
        if (day.dayId == dayId) return day;
      }
    }
    return null;
  }

  Future<void> savePlan(String key, WorkoutPlan plan) async {
    await _planBox.put(key, plan);
    _sync?.syncToCloud('workout_plans', key, plan.toJson());
  }

  Future<void> savePlanJson(String key, String jsonStr) async {
    // Validate JSON first
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object');
    }
    final map = decoded;
    
    if (map['planName'] == null || map['planName'].toString().trim().isEmpty) {
      throw const FormatException('Missing or empty "planName"');
    }
    
    final days = map['days'];
    if (days is! List) {
      throw const FormatException('"days" must be an array');
    }
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is! Map<String, dynamic>) {
        throw FormatException('Day at index $i is not an object');
      }
      
      final exercises = day['exercises'];
      if (exercises != null && exercises is! List) {
        throw FormatException('"exercises" in day "${day['dayName'] ?? 'unknown'}" must be an array');
      }
      
      if (exercises != null) {
        for (final ex in exercises) {
          if (ex is! Map<String, dynamic>) {
            throw const FormatException('Each exercise must be an object');
          }
          final name = ex['name']?.toString() ?? '';
          if (name.trim().isEmpty) {
            throw const FormatException('An exercise is missing a "name"');
          }
          final reps = ex['reps']?.toString() ?? '';
          if (reps.trim().isEmpty) {
            throw FormatException('Exercise "$name" is missing "reps"');
          }
          
          final yt = ex['youtubeUrl']?.toString() ?? '';
          if (yt.isNotEmpty) {
            if (!yt.contains('youtube.com/watch') && !yt.contains('youtu.be')) {
              throw FormatException('Invalid YouTube URL format for exercise "$name". Use youtube.com/watch or youtu.be');
            }
          }
        }
      }
    }
    final plan = WorkoutPlan.fromJson(map);
    await _planBox.put(key, plan);
    _sync?.syncToCloud('workout_plans', key, plan.toJson());
  }



  Future<void> finishWorkout(String date, String dayId) async {
    final key = '${date}_$dayId';
    final jsonStr = _sessionBox.get(key);
    Map<String, dynamic> data = {};
    if (jsonStr != null) {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    }
    data['finished'] = true;
    data['finishedAt'] = DateTime.now().toIso8601String();
    data['dayId'] = dayId;
    data['date'] = date;
    await _sessionBox.put(key, jsonEncode(data));
    
    _sync?.syncToCloud('workout_sessions', key, data);
  }

  bool isWorkoutFinished(String date, String dayId) {
    final key = '${date}_$dayId';
    final jsonStr = _sessionBox.get(key);
    if (jsonStr == null) return false;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return data['finished'] as bool? ?? false;
  }

  String? getRawPlanJson(String key) {
    final plan = _planBox.get(key);
    if (plan == null) return null;
    return jsonEncode(plan.toJson());
  }

  List<String> getPlanKeys() {
    return _planBox.keys.cast<String>().toList();
  }

  // ── Cloud sync helpers ──

  Future<void> importPlansFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_planBox.containsKey(entry.key)) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan);
      }
    }
  }

  /// Fetches global/public workout plans from Firebase and merges them locally.
  Future<void> fetchGlobalPlans() async {
    if (_sync == null) return;
    try {
      final globalData = await _sync!.pullGlobalCollection('public_workout_plans');
      for (final entry in globalData.entries) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching global workout plans: $e');
    }
  }

  /// Fetches the user's personal workout plans from Firebase and merges them locally.
  Future<void> fetchUserPlans() async {
    if (_sync == null) return;
    try {
      final userData = await _sync!.pullCollection('workout_plans');
      for (final entry in userData.entries) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching user workout plans: $e');
    }
  }

  Future<void> importSessionsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_sessionBox.containsKey(entry.key)) {
        await _sessionBox.put(entry.key, jsonEncode(entry.value));
      }
    }
  }

  Map<String, Map<String, dynamic>> exportPlansForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _planBox.keys) {
      final plan = _planBox.get(key as String);
      if (plan != null) result[key] = plan.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportSessionsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _sessionBox.keys) {
      final sessionStr = _sessionBox.get(key as String);
      if (sessionStr != null) result[key] = jsonDecode(sessionStr) as Map<String, dynamic>;
    }
    return result;
  }
}

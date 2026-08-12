import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/daily_meal_log.dart';
import '../models/meal_plan.dart';
import 'package:flutter/services.dart';
import '../interfaces/i_cloud_sync_service.dart';
import 'package:flutter/foundation.dart';

class MealRepository {
  static const String _dailyLogsBoxName = 'daily_meal_logs_v2';
  static const String _planBoxName = 'meal_plans_v2';

  late Box<DailyMealLog> _dailyLogsBox;
  late Box<MealPlan> _planBox;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _dailyLogsBox = await Hive.openBox<DailyMealLog>(_dailyLogsBoxName);
    _planBox = await Hive.openBox<MealPlan>(_planBoxName);
    
    // Quick migration to rename the default plan if the user disliked it.
    final existingPlan = _planBox.get('standard_plan');
    if (existingPlan != null && existingPlan.planName == '1200 kcal Cutting Plan') {
      final updatedPlan = existingPlan.copyWith(planName: 'Daily Nutrition Plan');
      await _planBox.put('standard_plan', updatedPlan);
    }
    
    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    if (_planBox.isEmpty) {
      final jsonStr = await rootBundle.loadString('assets/data/seed_meal_plan.json');
      final plan = MealPlan.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      _planBox.put('standard_plan', plan);
    }
  }

  // Legacy migrations removed, handled by V2 migration now.

  DailyMealLog getDailyLog(String date) {
    return _dailyLogsBox.get(date) ?? DailyMealLog(date: date);
  }

  List<DailyMealLog> getLogsInRange(String start, String end) {
    final logs = <DailyMealLog>[];
    for (final key in _dailyLogsBox.keys) {
      final dateStr = key as String;
      if (dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0) {
        final log = _dailyLogsBox.get(key);
        if (log != null) {
          logs.add(log);
        }
      }
    }
    return logs;
  }

  Future<void> saveDailyLog(DailyMealLog log) async {
    await _dailyLogsBox.put(log.date, log);
    _sync?.syncToCloud('meal_logs', log.date, log.toJson());
  }

  Future<void> saveMealSlot(String date, String slotId, MealSlotLog slotLog) async {
    final currentLog = getDailyLog(date);
    final updatedSlots = Map<String, MealSlotLog>.from(currentLog.customSlots);
    updatedSlots[slotId] = slotLog;
    
    final updated = currentLog.copyWith(customSlots: updatedSlots);
    await saveDailyLog(updated);
  }

  Future<void> clearMealSlot(String date, String slotId) async {
    final currentLog = getDailyLog(date);
    final updatedSlots = Map<String, MealSlotLog>.from(currentLog.customSlots);
    updatedSlots.remove(slotId);
    
    final updated = currentLog.copyWith(customSlots: updatedSlots);
    await saveDailyLog(updated);
  }

  MealPlan? getMealPlan(String key) {
    return _planBox.get(key);
  }

  Future<void> savePlanJson(String key, String jsonStr) async {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object');
    }
    final map = decoded;
    if (map['planName'] == null || map['planName'].toString().trim().isEmpty) {
      throw const FormatException('Missing or empty "planName"');
    }
    final meals = map['meals'];
    if (meals is! List) {
      throw const FormatException('"meals" must be an array');
    }
    final plan = MealPlan.fromJson(map);
    await _planBox.put(key, plan);
    _sync?.syncToCloud('meal_plans', key, plan.toJson());
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

  Future<void> importLogsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_dailyLogsBox.containsKey(entry.key)) {
        final log = DailyMealLog.fromJson(entry.value);
        await _dailyLogsBox.put(entry.key, log);
      }
    }
  }

  Map<String, Map<String, dynamic>> exportLogsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final log in _dailyLogsBox.values) {
      result[log.date] = log.toJson();
    }
    return result;
  }

  Future<void> importPlansFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      if (!_planBox.containsKey(entry.key)) {
        final plan = MealPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan);
      }
    }
  }

  /// Fetches global/public meal plans from Firebase and merges them locally.
  Future<void> fetchGlobalPlans() async {
    if (_sync == null) return;
    try {
      final globalData = await _sync!.pullGlobalCollection('public_meal_plans');
      for (final entry in globalData.entries) {
        final plan = MealPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching global meal plans: $e');
    }
  }

  /// Fetches the user's personal meal plans from Firebase and merges them locally.
  Future<void> fetchUserPlans() async {
    if (_sync == null) return;
    try {
      final userData = await _sync!.pullCollection('meal_plans');
      for (final entry in userData.entries) {
        final plan = MealPlan.fromJson(entry.value);
        await _planBox.put(entry.key, plan); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching user meal plans: $e');
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
}

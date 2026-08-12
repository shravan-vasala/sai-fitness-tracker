import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/daily_log.dart';
import '../models/exercise_log.dart';
import '../models/habit.dart';
import '../models/body_stats.dart';
import '../models/daily_meal_log.dart';

class CsvExportService {
  Future<String?> exportData(DateTime? startDate) async {
    try {
      final archive = Archive();

      Future<void> addCsv(String name, String? csvText) async {
        if (csvText == null || csvText.isEmpty) return;
        final bytes = utf8.encode(csvText);
        archive.addFile(ArchiveFile.bytes(name, bytes));
      }

      await addCsv('daily_logs.csv', await _exportDailyLogs(startDate));
      await addCsv('exercise_logs.csv', await _exportExerciseLogs(startDate));
      await addCsv('habits.csv', await _exportHabitCompletions(startDate));
      await addCsv('body_stats.csv', await _exportBodyStats(startDate));
      await addCsv('meals.csv', await _exportMeals(startDate));

      if (archive.isEmpty) return null;

      final zipData = ZipEncoder().encode(archive);

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'trufit_export_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File('${tempDir.path}/$fileName');
      await zipFile.writeAsBytes(zipData);

      return zipFile.path;
    } catch (e) {
      print('Export error: $e');
      return null;
    }
  }

  Future<Box<T>> _openTypedBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    try {
      return await Hive.openBox<T>(boxName);
    } catch (_) {
      return Hive.box<T>(boxName);
    }
  }

  bool _isAfterStartDate(String dateStr, DateTime? startDate) {
    if (startDate == null) return true;
    try {
      final date = DateTime.parse(dateStr);
      return date.isAfter(startDate.subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  Future<String?> _exportDailyLogs(DateTime? startDate) async {
    final box = await _openTypedBox<DailyLog>('daily_logs_v2');
    final rows = <List<dynamic>>[];
    
    // Headers
    rows.add(['Date', 'Weight', 'Steps', 'Steps Source', 'Sleep Hours', 'Sleep Source', 'Body Fat', 'Workout Completed', 'Workout Day ID']);

    for (final log in box.values) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        rows.add([
          log.date,
          log.weight ?? '',
          log.steps ?? '',
          log.stepsSource ?? '',
          log.sleepHours ?? '',
          log.sleepSource ?? '',
          log.bodyFat ?? '',
          log.workoutCompleted,
          log.workoutDayId ?? '',
        ]);
      } catch (_) {}
    }

    if (rows.length == 1) return null; // Only headers
    return csv.encode(rows);
  }

  Future<String?> _exportExerciseLogs(DateTime? startDate) async {
    final box = await _openTypedBox<ExerciseLog>('exercise_logs_v2');
    final rows = <List<dynamic>>[];
    
    rows.add(['Date', 'Exercise', 'Set', 'Reps', 'Weight']);

    for (final log in box.values) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        for (final set in log.sets) {
          rows.add([
            log.date,
            log.exerciseName,
            set.setNumber,
            set.reps,
            set.weight,
          ]);
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportHabitCompletions(DateTime? startDate) async {
    final box = await _openTypedBox<HabitCompletion>('habit_completions_v2');
    final habitBox = await _openTypedBox<Habit>('habit_config_v2');
    
    final habits = <String, Habit>{};
    for (final h in habitBox.values) {
      try {
        habits[h.id] = h;
      } catch (_) {}
    }

    final rows = <List<dynamic>>[];
    rows.add(['Date', 'Habit ID', 'Habit Name', 'Value', 'Override']);

    for (final completion in box.values) {
      try {
        if (!_isAfterStartDate(completion.date, startDate)) continue;

        for (final entry in completion.completions.entries) {
          final habitId = entry.key;
          final habitName = habits[habitId]?.name ?? habitId;
          final val = entry.value;
          final override = completion.overrides[habitId] ?? '';
          
          rows.add([
            completion.date,
            habitId,
            habitName,
            val,
            override,
          ]);
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportBodyStats(DateTime? startDate) async {
    final box = await _openTypedBox<BodyStats>('body_stats_v2');
    final rows = <List<dynamic>>[];
    
    rows.add(['Date', 'Unit', 'Waist', 'Hips', 'Chest', 'Left Arm', 'Right Arm', 'Left Thigh', 'Right Thigh', 'Neck']);

    for (final stats in box.values) {
      try {
        if (!_isAfterStartDate(stats.date, startDate)) continue;

        rows.add([
          stats.date,
          stats.unit,
          stats.waist ?? '',
          stats.hips ?? '',
          stats.chest ?? '',
          stats.leftArm ?? '',
          stats.rightArm ?? '',
          stats.leftThigh ?? '',
          stats.rightThigh ?? '',
          stats.neck ?? '',
        ]);
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }

  Future<String?> _exportMeals(DateTime? startDate) async {
    final box = await _openTypedBox<DailyMealLog>('daily_meal_logs_v2');
    final rows = <List<dynamic>>[];
    
    rows.add(['Date', 'Slot', 'Total Calories', 'Total Protein (g)', 'Total Carbs (g)', 'Total Fat (g)']);

    for (final log in box.values) {
      try {
        if (!_isAfterStartDate(log.date, startDate)) continue;

        for (final entry in log.customSlots.entries) {
          final slotName = entry.key;
          final slot = entry.value;
          
          if (slot.totalCalories > 0 || slot.items.isNotEmpty) {
            rows.add([
              log.date,
              slotName,
              slot.totalCalories,
              slot.totalProtein,
              slot.totalCarbs,
              slot.totalFat,
            ]);
          }
        }
      } catch (_) {}
    }

    if (rows.length == 1) return null;
    return csv.encode(rows);
  }
}

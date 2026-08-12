import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_providers.dart';

final mealStreakProvider = Provider<int>((ref) {
  final mealRepo = ref.watch(mealRepoProvider);
  
  // Watch current day's log to trigger rebuilds when user logs a meal today
  ref.watch(dailyMealLogProvider);
  
  final now = DateTime.now();
  final endStr = DateFormat('yyyy-MM-dd').format(now);
  final startStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30)));
  
  final logs = mealRepo.getLogsInRange(startStr, endStr);
  
  final sortedLogs = logs
    .where((log) => log.customSlots.values.any((s) => s.items.isNotEmpty || s.totalCalories > 0))
    .map((log) => log.date)
    .toList()
    ..sort((a, b) => b.compareTo(a));

  if (sortedLogs.isEmpty) return 0;

  int streak = 0;
  DateTime? lastDate;

  // We need to parse just the date part for 'now' to compare accurately
  final todayDate = DateTime(now.year, now.month, now.day);

  for (final dateStr in sortedLogs) {
    final date = DateFormat('yyyy-MM-dd').parse(dateStr);
    if (lastDate == null) {
      // If the most recent log isn't today or yesterday, streak is 0
      final diffToToday = todayDate.difference(date).inDays;
      if (diffToToday > 1) {
        return 0; // Streak broken before today/yesterday
      }
      streak++;
      lastDate = date;
    } else {
      final diff = lastDate.difference(date).inDays;
      if (diff == 1) {
        streak++;
        lastDate = date;
      } else {
        break;
      }
    }
  } // End of for loop
  return streak;
});

final stepsStreakProvider = Provider<int>((ref) {
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final habits = ref.watch(habitsProvider);
  
  // Watch current day's log to trigger rebuilds when user logs steps today
  ref.watch(dailyLogProvider);

  double stepsTarget = 10000;
  for (final h in habits) {
    if (h.name.toLowerCase().contains('steps') || h.name.toLowerCase().contains('walk')) {
      stepsTarget = h.target.toDouble();
      break;
    }
  }

  final logs = dailyLogRepo.getAllLogs()
    .where((log) => log.steps != null && log.steps! >= stepsTarget)
    .map((log) => log.date)
    .toList()
    ..sort((a, b) => b.compareTo(a));

  if (logs.isEmpty) return 0;

  int streak = 0;
  DateTime? lastDate;
  final now = DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);

  for (final dateStr in logs) {
    final date = DateFormat('yyyy-MM-dd').parse(dateStr);
    if (lastDate == null) {
      final diffToToday = todayDate.difference(date).inDays;
      if (diffToToday > 1) return 0; // Streak broken before today/yesterday
      streak++;
      lastDate = date;
    } else {
      final diff = lastDate.difference(date).inDays;
      if (diff == 1) {
        streak++;
        lastDate = date;
      } else {
        break;
      }
    }
  }
  return streak;
});

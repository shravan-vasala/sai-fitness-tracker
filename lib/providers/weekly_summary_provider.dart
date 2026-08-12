import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_providers.dart';
import '../models/daily_log.dart';
import '../models/habit.dart';
import '../utils/workout_completion.dart';

class WeeklySummary {
  final int workoutsCompleted;
  final int workoutsTotal;
  final double habitCompletionRate; // 0.0 to 1.0
  final String? bestHabit;
  final int avgSteps;
  final int bestSteps;
  final double avgSleep;
  final int nightsUnder7h;
  final int avgCalories;
  final int targetCalories;
  final int daysOverCalories;
  final int daysUnderCalories;
  final double weightDelta; // end - start
  final List<double> dailyHabitRates; // 7 items (Mon-Sun)
  final int weekScore; // 0 to 100

  WeeklySummary({
    required this.workoutsCompleted,
    required this.workoutsTotal,
    required this.habitCompletionRate,
    this.bestHabit,
    required this.avgSteps,
    required this.bestSteps,
    required this.avgSleep,
    required this.nightsUnder7h,
    required this.avgCalories,
    required this.targetCalories,
    required this.daysOverCalories,
    required this.daysUnderCalories,
    required this.weightDelta,
    required this.dailyHabitRates,
    required this.weekScore,
  });

  String generateShareText() {
    final sb = StringBuffer();
    sb.writeln('My Weekly Fitness Summary');
    sb.writeln('Score: $weekScore/100');
    sb.writeln('---');
    sb.writeln('Workouts: $workoutsCompleted/$workoutsTotal');
    sb.writeln('Habits: ${(habitCompletionRate * 100).toInt()}% completion');
    if (bestHabit != null) sb.writeln('Best Habit: $bestHabit');
    if (avgSteps > 0) sb.writeln('Avg Steps: $avgSteps (Best: $bestSteps)');
    if (avgSleep > 0) sb.writeln('Avg Sleep: ${avgSleep.toStringAsFixed(1)}h');
    if (avgCalories > 0) sb.writeln('Avg Calories: $avgCalories kcal');
    if (weightDelta != 0) {
      final deltaStr = weightDelta > 0 ? '+${weightDelta.toStringAsFixed(1)}' : weightDelta.toStringAsFixed(1);
      sb.writeln('Weight Change: $deltaStr');
    }
    sb.writeln('---');
    sb.writeln('Tracked with Sthira');
    return sb.toString();
  }
}

final weeklySummaryProvider = Provider<WeeklySummary>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  
  // Find Monday (1) and Sunday (7)
  final weekday = selectedDate.weekday;
  final startOfWeek = selectedDate.subtract(Duration(days: weekday - 1));
  final endOfWeek = startOfWeek.add(Duration(days: 6));
  
  final startStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
  final endStr = DateFormat('yyyy-MM-dd').format(endOfWeek);
  
  // Fetch data
  final dailyLogs = ref.watch(dailyLogsRangeProvider((startStr, endStr)));
  final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
  final profile = ref.watch(profileProvider);
  
  final habitRepo = ref.watch(habitRepoProvider);
  final workoutPlan = ref.watch(workoutPlanProvider);
  final exerciseLogRepo = ref.watch(exerciseLogRepoProvider);
  ref.watch(exerciseLogsUpdateProvider);
  
  // Calculate Workouts
  int wCompleted = 0;
  int wTotal = 0;
  
  if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
    for (int i = 0; i < 7; i++) {
      final d = startOfWeek.add(Duration(days: i));
      final workoutDay = WorkoutCompletion.resolveWorkoutDay(workoutPlan, d);
      final isRest = WorkoutCompletion.isRestDay(workoutDay, d);
      final sectionsTotal = isRest ? 1 : workoutDay.sections.length;
      wTotal += sectionsTotal;
      
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = dailyLogs.firstWhere((dl) => dl.date == dateStr, orElse: () => DailyLog(date: dateStr));
      
      if (isRest) {
        if (WorkoutCompletion.isDayWorkoutDone(
          date: dateStr,
          day: workoutDay,
          dateTime: d,
          hasLog: exerciseLogRepo.hasLog,
          dailyLog: log,
        )) {
          wCompleted++;
        }
      } else {
        wCompleted += WorkoutCompletion.completedSectionCount(
          dateStr,
          workoutDay,
          exerciseLogRepo.hasLog,
        );
      }
    }
  } else {
    // If no plan, fallback to simple daily log checks
    wTotal = 7;
    wCompleted = dailyLogs.where((l) => l.workoutCompleted).length;
  }
  
  // Calculate Habits
  final habits = ref.watch(habitsProvider);
  int totalHabitInstances = 0;
  int completedHabitInstances = 0;
  List<double> dailyRates = List.filled(7, 0.0);
  Map<String, int> habitStreaksThisWeek = {};
  
  if (habits.isNotEmpty) {
    for (int i = 0; i < 7; i++) {
      final d = startOfWeek.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final completions = habitRepo.getCompletions(dateStr);
      final log = dailyLogs.firstWhere((dl) => dl.date == dateStr, orElse: () => DailyLog(date: dateStr));
      
      int dailyDone = 0;
      for (final h in habits) {
        if (isHabitCompleted(h, completions, log)) {
          dailyDone++;
          habitStreaksThisWeek[h.name] = (habitStreaksThisWeek[h.name] ?? 0) + 1;
        }
      }
      totalHabitInstances += habits.length;
      completedHabitInstances += dailyDone;
      dailyRates[i] = dailyDone / habits.length;
    }
  }
  
  final habitCompletionRate = totalHabitInstances > 0 ? (completedHabitInstances / totalHabitInstances) : 0.0;
  String? bestHabit;
  int maxHabitStreak = 0;
  habitStreaksThisWeek.forEach((key, value) {
    if (value > maxHabitStreak) {
      maxHabitStreak = value;
      bestHabit = key;
    }
  });

  // Calculate Steps & Sleep
  int sumSteps = 0;
  int daysWithSteps = 0;
  int bestSteps = 0;
  
  double sumSleep = 0;
  int daysWithSleep = 0;
  int nightsUnder7h = 0;
  
  for (final log in dailyLogs) {
    if (log.steps != null && log.steps! > 0) {
      sumSteps += log.steps!;
      daysWithSteps++;
      if (log.steps! > bestSteps) bestSteps = log.steps!;
    }
    if (log.sleepHours != null && log.sleepHours! > 0) {
      sumSleep += log.sleepHours!;
      daysWithSleep++;
      if (log.sleepHours! < 7.0) nightsUnder7h++;
    }
  }
  
  final avgSteps = daysWithSteps > 0 ? sumSteps ~/ daysWithSteps : 0;
  final avgSleep = daysWithSleep > 0 ? sumSleep / daysWithSleep : 0.0;
  
  // Calculate Calories
  int sumCalories = 0;
  int daysWithCalories = 0;
  int daysOver = 0;
  int daysUnder = 0;
  
  for (final mealLog in mealLogs) {
    final cals = mealLog.totalCalories;
    if (cals > 0) {
      sumCalories += cals;
      daysWithCalories++;
      if (cals > profile.targetCalories) {
        daysOver++;
      } else {
        daysUnder++;
      }
    }
  }
  
  final avgCalories = daysWithCalories > 0 ? sumCalories ~/ daysWithCalories : 0;
  
  // Calculate Weight Delta
  double firstWeight = 0;
  double lastWeight = 0;
  // Sort logs by date to find first and last weight
  final sortedLogs = List<DailyLog>.from(dailyLogs)..sort((a, b) => a.date.compareTo(b.date));
  for (final log in sortedLogs) {
    if (log.weight != null && log.weight! > 0) {
      if (firstWeight == 0) firstWeight = log.weight!;
      lastWeight = log.weight!;
    }
  }
  final weightDelta = (firstWeight > 0 && lastWeight > 0 && firstWeight != lastWeight) 
      ? (lastWeight - firstWeight) 
      : 0.0;
      
  // Calculate Week Score (0-100)
  // Weighting: 50% workouts, 50% habits (if both present)
  double workoutScore = wTotal > 0 ? (wCompleted / wTotal) : 1.0; // If no workouts planned, don't penalize
  double habitScore = habitCompletionRate;
  
  int weekScore = ((workoutScore * 0.5 + habitScore * 0.5) * 100).toInt();
  if (wTotal == 0) {
    weekScore = (habitScore * 100).toInt();
  } else if (habits.isEmpty) {
    weekScore = (workoutScore * 100).toInt();
  }

  return WeeklySummary(
    workoutsCompleted: wCompleted,
    workoutsTotal: wTotal,
    habitCompletionRate: habitCompletionRate,
    bestHabit: bestHabit,
    avgSteps: avgSteps,
    bestSteps: bestSteps,
    avgSleep: avgSleep,
    nightsUnder7h: nightsUnder7h,
    avgCalories: avgCalories,
    targetCalories: profile.targetCalories,
    daysOverCalories: daysOver,
    daysUnderCalories: daysUnder,
    weightDelta: weightDelta,
    dailyHabitRates: dailyRates,
    weekScore: weekScore,
  );
});

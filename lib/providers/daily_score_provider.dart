import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/habit.dart';
import '../models/daily_log.dart';
import '../utils/workout_completion.dart';

class DailyScore {
  final int totalScore;
  final bool isFutureDate;
  final double habitsScore;
  final double habitsMax;
  final double workoutsScore;
  final double workoutsMax;
  final double mealsScore;
  final double mealsMax;
  final double stepsScore;
  final double stepsMax;
  final double waterScore;
  final double waterMax;

  DailyScore({
    required this.totalScore,
    required this.isFutureDate,
    required this.habitsScore,
    required this.habitsMax,
    required this.workoutsScore,
    required this.workoutsMax,
    required this.mealsScore,
    required this.mealsMax,
    required this.stepsScore,
    required this.stepsMax,
    required this.waterScore,
    required this.waterMax,
  });

  static bool _bucketFull(double score, double max) =>
      max <= 0 || score >= max - 0.01;

  /// Habits + meals + workouts fully earned (steps are bonus-only).
  bool get isPrimaryComplete {
    if (isFutureDate) return false;
    return _bucketFull(habitsScore, habitsMax) &&
        _bucketFull(mealsScore, mealsMax) &&
        _bucketFull(workoutsScore, workoutsMax);
  }

  /// Compact labels for Home "still to do" cue.
  List<String> get remainingLabels {
    if (isFutureDate) return const [];
    final labels = <String>[];
    if (habitsMax > 0 && !_bucketFull(habitsScore, habitsMax)) {
      labels.add('habits');
    }
    if (mealsMax > 0 && !_bucketFull(mealsScore, mealsMax)) {
      labels.add('meals');
    }
    if (workoutsMax > 0 && !_bucketFull(workoutsScore, workoutsMax)) {
      labels.add('workout');
    }
    return labels;
  }
}

final dailyScoreProvider = Provider<DailyScore>((ref) {
  final dateStr = ref.watch(dateStringProvider);
  final date = DateTime.parse(dateStr);
  final today = DateTime.now();
  final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

  if (isFuture) {
    return DailyScore(
      totalScore: 0,
      isFutureDate: true,
      habitsScore: 0,
      habitsMax: 0,
      workoutsScore: 0,
      workoutsMax: 0,
      mealsScore: 0,
      mealsMax: 0,
      stepsScore: 0,
      stepsMax: 0,
      waterScore: 0,
      waterMax: 0,
    );
  }

  // 1. Habits (Max 40)
  final habits = ref.watch(habitsProvider);
  final habitCompletions = ref.watch(habitCompletionsProvider);
  
  final steps = ref.watch(dailyLogProvider.select((d) => d.steps));
  final sleepHours = ref.watch(dailyLogProvider.select((d) => d.sleepHours));
  final workoutCompleted = ref.watch(dailyLogProvider.select((d) => d.workoutCompleted));
  final waterMl = ref.watch(dailyLogProvider.select((d) => d.waterMl));
  final dailyLog = DailyLog(
    date: dateStr,
    steps: steps,
    sleepHours: sleepHours,
    workoutCompleted: workoutCompleted,
    waterMl: waterMl,
  );
  
  double habitsScore = 0;
  double habitsMax = 40;
  bool hasStepsHabit = false;
  double stepsTarget = 10000;

  if (habits.isNotEmpty) {
    int habitsDone = 0;
    for (final h in habits) {
      if (h.name.toLowerCase().contains('steps') || h.name.toLowerCase().contains('walk')) {
        hasStepsHabit = true;
        stepsTarget = h.target.toDouble();
      }
      if (isHabitCompleted(h, habitCompletions, dailyLog)) {
        habitsDone++;
      }
    }
    habitsScore = (habitsDone / habits.length) * habitsMax;
  }

  // 2. Workouts (Max 30)
  double workoutsScore = 0;
  double workoutsMax = 30;
  final workoutPlan = ref.watch(workoutPlanProvider);
  final logRepo = ref.watch(exerciseLogRepoProvider);
  ref.watch(exerciseLogsUpdateProvider);
  
  if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
    final day = WorkoutCompletion.resolveWorkoutDay(workoutPlan, date);

    if (WorkoutCompletion.isRestDay(day, date)) {
      // Planned rest counts as full workout points
      workoutsScore = workoutsMax;
    } else {
      final workoutsTotal = day.sections.length;
      if (workoutsTotal > 0) {
        final workoutsDone = WorkoutCompletion.completedSectionCount(
          dateStr,
          day,
          logRepo.hasLog,
        );
        workoutsScore = (workoutsDone / workoutsTotal) * workoutsMax;
        // Finish-early: day flagged complete even if sections incomplete
        if (workoutCompleted && workoutsDone < workoutsTotal) {
          workoutsScore = workoutsMax;
        }
      }
    }
  } else {
    // No plan, just rely on the manual workout completed button
    if (workoutCompleted) workoutsScore = workoutsMax;
  }

  // 3. Meals (Max 20)
  double mealsScore = 0;
  double mealsMax = 20;
  final mealPlanMeals = ref.watch(mealPlanProvider.select((p) => p?.meals.map((m) => m.type).toList()));
  final mealLogSlots = ref.watch(dailyMealLogProvider.select((m) => m.customSlots.keys.toList()));
  
  if (mealPlanMeals != null && mealPlanMeals.isNotEmpty) {
    int slotsLogged = 0;
    int slotsTotal = mealPlanMeals.length;
    
    for (final slotType in mealPlanMeals) {
      if (mealLogSlots.contains(slotType)) {
        slotsLogged++;
      }
    }
    mealsScore = (slotsLogged / slotsTotal) * mealsMax;
  }

  // 4. Steps (Max 10) - only if steps habit exists
  double stepsScore = 0;
  double stepsMax = hasStepsHabit ? 10 : 0;
  
  if (hasStepsHabit && stepsTarget > 0) {
    final actualSteps = steps ?? 0;
    final fraction = (actualSteps / stepsTarget).clamp(0.0, 1.0);
    stepsScore = fraction * stepsMax;
  }

  // 5. Water (Max 10) - only if water habit exists
  bool hasWaterHabit = false;
  double waterTarget = 2000;
  for (final h in habits) {
    if (h.name.toLowerCase().contains('water')) {
      hasWaterHabit = true;
      waterTarget = h.target.toDouble();
      if (h.unit.toLowerCase() == 'l' || h.unit.toLowerCase() == 'liters') {
        waterTarget *= 1000;
      }
      break;
    }
  }
  
  double waterScore = 0;
  double waterMax = hasWaterHabit ? 10 : 0;
  
  if (hasWaterHabit && waterTarget > 0) {
    final actualWater = dailyLog.waterMl ?? 0;
    final fraction = (actualWater / waterTarget).clamp(0.0, 1.0);
    waterScore = fraction * waterMax;
  }

  // Calculate final score
  final totalEarned = habitsScore + workoutsScore + mealsScore + stepsScore + waterScore;
  final totalPossible = habitsMax + workoutsMax + mealsMax + stepsMax + waterMax;
  
  int finalScore = 0;
  if (totalPossible > 0) {
    finalScore = ((totalEarned / totalPossible) * 100).round();
  }

  return DailyScore(
    totalScore: finalScore,
    isFutureDate: false,
    habitsScore: habitsScore,
    habitsMax: habitsMax,
    workoutsScore: workoutsScore,
    workoutsMax: workoutsMax,
    mealsScore: mealsScore,
    mealsMax: mealsMax,
    stepsScore: stepsScore,
    stepsMax: stepsMax,
    waterScore: waterScore,
    waterMax: waterMax,
  );
});

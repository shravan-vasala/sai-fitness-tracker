import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_log.dart';
import '../models/workout_plan.dart';
import '../providers/app_providers.dart';
import '../utils/pr_calculator.dart';
import '../utils/workout_completion.dart';

String parseRepTarget(String rep) {
  if (rep.contains('-')) {
    final parts = rep.split('-');
    if (parts.length == 2) return parts[1].trim();
  }
  return rep;
}

List<SetLog> buildPlannedSets(Exercise exercise, ExerciseLog? lastLog) {
  return List.generate(exercise.setCount, (i) {
    final reps = int.tryParse(parseRepTarget(exercise.reps[i])) ?? 0;
    double weight = exercise.weightKg ?? 0;
    if (weight <= 0 && lastLog != null && i < lastLog.sets.length) {
      weight = lastLog.sets[i].weight;
    }
    return SetLog(setNumber: i + 1, reps: reps, weight: weight);
  });
}

ExerciseLog? mostRecentPriorLog({
  required List<ExerciseLog> allLogs,
  required String beforeDate,
}) {
  final beforeToday =
      allLogs.where((l) => l.date.compareTo(beforeDate) < 0).toList();
  if (beforeToday.isEmpty) return null;
  beforeToday.sort((a, b) => a.date.compareTo(b.date));
  return beforeToday.last;
}

/// Saves an exercise log and applies PR / day-complete / rest-timer side effects.
Future<PrCalculationResult> saveExerciseSets({
  required WidgetRef ref,
  required Exercise exercise,
  required List<SetLog> sets,
  bool startRestTimer = true,
}) async {
  final dateStr = ref.read(dateStringProvider);
  final repo = ref.read(exerciseLogRepoProvider);
  final currentPr = repo.getPr(exercise.name);

  final log = ExerciseLog(
    date: dateStr,
    exerciseName: exercise.name,
    sets: sets,
  );
  await repo.saveLog(log);

  final prResult = PrCalculator.calculateNewPr(log, currentPr);
  if (prResult.hasAnyNewPr) {
    await repo.savePr(prResult.newPr);
  }

  final plan = ref.read(workoutPlanProvider);
  if (plan != null && plan.days.isNotEmpty) {
    final date = DateTime.parse(dateStr);
    final day = WorkoutCompletion.resolveWorkoutDay(plan, date);
    if (!WorkoutCompletion.isRestDay(day, date) &&
        WorkoutCompletion.isTrainingDayCompleteWithRepo(dateStr, day, repo)) {
      final dailyLog = ref.read(dailyLogProvider);
      if (!dailyLog.workoutCompleted) {
        await ref.read(dailyLogProvider.notifier).markWorkoutCompleted(day.dayId);
      }
    }
  }

  ref.read(exerciseLogsUpdateProvider.notifier).state++;
  ref.invalidate(dailyScoreProvider);
  ref.invalidate(dailyLogProvider);

  if (startRestTimer && exercise.restSecondsAfterSet > 0) {
    ref.read(restTimerProvider.notifier).startTimer(
          exercise.restSecondsAfterSet,
          exerciseName: exercise.name,
        );
  }

  HapticFeedback.mediumImpact();
  return prResult;
}

Future<PrCalculationResult> saveExerciseAsPlanned({
  required WidgetRef ref,
  required Exercise exercise,
}) async {
  final dateStr = ref.read(dateStringProvider);
  final repo = ref.read(exerciseLogRepoProvider);
  final lastLog = mostRecentPriorLog(
    allLogs: repo.getLogsForExercise(exercise.name),
    beforeDate: dateStr,
  );
  final sets = buildPlannedSets(exercise, lastLog);
  return saveExerciseSets(ref: ref, exercise: exercise, sets: sets);
}

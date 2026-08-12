import '../models/daily_log.dart';
import '../models/workout_plan.dart';
import '../repositories/exercise_log_repository.dart';

/// Shared workout completion rules (Approach A):
/// - [ExerciseLog] is the source of truth for exercise/section completion.
/// - [DailyLog.workoutCompleted] is the day-level Finish flag (full or early).
/// - Planned rest days count as done for scoring / day-done checks.
class WorkoutCompletion {
  /// Sunday or a day with no workout sections.
  static bool isRestDay(WorkoutDay day, DateTime date) {
    return date.weekday == DateTime.sunday || day.sections.isEmpty;
  }

  /// Resolves the scheduled [WorkoutDay] for [date] using the same index rules
  /// as Home / daily score (Sunday → Rest id, else weekday-1).
  static WorkoutDay resolveWorkoutDay(WorkoutPlan plan, DateTime date) {
    final isSunday = date.weekday == DateTime.sunday;
    final dayIndex =
        isSunday ? 0 : (date.weekday - 1).clamp(0, plan.days.length - 1);
    final dayIdTarget =
        isSunday ? 'Rest' : plan.days[dayIndex].dayId;
    return plan.days.firstWhere(
      (d) => d.dayId == dayIdTarget,
      orElse: () => plan.days[dayIndex],
    );
  }

  static bool isSectionComplete(
    String date,
    WorkoutSection section,
    bool Function(String date, String exerciseName) hasLog,
  ) {
    return section.exercises.isNotEmpty &&
        section.exercises.every((ex) => hasLog(date, ex.name));
  }

  static bool isSectionCompleteWithRepo(
    String date,
    WorkoutSection section,
    ExerciseLogRepository repo,
  ) {
    return isSectionComplete(date, section, repo.hasLog);
  }

  /// True when every section on a training day has all exercises logged.
  static bool isTrainingDayComplete(
    String date,
    WorkoutDay day,
    bool Function(String date, String exerciseName) hasLog,
  ) {
    if (day.sections.isEmpty) return false;
    return day.sections.every((sec) => isSectionComplete(date, sec, hasLog));
  }

  static bool isTrainingDayCompleteWithRepo(
    String date,
    WorkoutDay day,
    ExerciseLogRepository repo,
  ) {
    return isTrainingDayComplete(date, day, repo.hasLog);
  }

  /// Day-level "workout done" for score / summaries.
  /// Rest → always true (planned rest). Training → all logs or Finish flag.
  static bool isDayWorkoutDone({
    required String date,
    required WorkoutDay day,
    required DateTime dateTime,
    required bool Function(String date, String exerciseName) hasLog,
    required DailyLog dailyLog,
  }) {
    if (isRestDay(day, dateTime)) return true;
    return isTrainingDayComplete(date, day, hasLog) ||
        dailyLog.workoutCompleted;
  }

  static bool isDayWorkoutDoneWithRepo({
    required String date,
    required WorkoutDay day,
    required DateTime dateTime,
    required ExerciseLogRepository repo,
    required DailyLog dailyLog,
  }) {
    return isDayWorkoutDone(
      date: date,
      day: day,
      dateTime: dateTime,
      hasLog: repo.hasLog,
      dailyLog: dailyLog,
    );
  }

  /// Count of fully logged sections on a training day.
  static int completedSectionCount(
    String date,
    WorkoutDay day,
    bool Function(String date, String exerciseName) hasLog,
  ) {
    var count = 0;
    for (final sec in day.sections) {
      if (isSectionComplete(date, sec, hasLog)) count++;
    }
    return count;
  }
}

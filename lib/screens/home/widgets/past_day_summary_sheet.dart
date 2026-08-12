import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../models/habit.dart';
import '../../../router/app_router.dart';
import '../../../utils/workout_completion.dart';

class PastDaySummarySheet extends ConsumerWidget {
  final DateTime date;

  const PastDaySummarySheet({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Watch trigger for reactivity on updates
    ref.watch(dailyLogProvider);
    ref.watch(habitCompletionsProvider);

    // Synchronous reads from repos
    final dailyLog = ref.read(dailyLogRepoProvider).getOrCreate(dateStr);
    final mealLog = ref.read(mealRepoProvider).getDailyLog(dateStr);
    final allHabits = ref.read(habitRepoProvider).getHabits();
    final habitCompletions = ref.read(habitRepoProvider).getCompletions(dateStr);

    final applicableHabits = allHabits.where((h) {
      final habitDate = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      final sDate = DateTime(date.year, date.month, date.day);
      return !habitDate.isAfter(sDate);
    }).toList();
    
    
    final workoutPlan = ref.read(workoutPlanProvider);
    final profile = ref.read(profileProvider);

    // 1) Compute workout status
    bool isRestDay = true;
    int totalExercises = 0;
    int completedExercises = 0;
    String workoutDayName = "Rest Day";
    String? currentWorkoutDayId;
    bool workoutDayDone = false;

    if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
      final workoutDay = WorkoutCompletion.resolveWorkoutDay(workoutPlan, date);
      final logRepo = ref.read(exerciseLogRepoProvider);
      isRestDay = WorkoutCompletion.isRestDay(workoutDay, date);
      workoutDayDone = WorkoutCompletion.isDayWorkoutDoneWithRepo(
        date: dateStr,
        day: workoutDay,
        dateTime: date,
        repo: logRepo,
        dailyLog: dailyLog,
      );

      if (!isRestDay) {
        workoutDayName = workoutDay.label ?? 'Workout Day';
        currentWorkoutDayId = dailyLog.workoutDayId ?? workoutDay.dayId;
        totalExercises = workoutDay.sections.expand((s) => s.exercises).length;
        completedExercises = workoutDay.sections
            .expand((s) => s.exercises)
            .where((e) => logRepo.hasLog(dateStr, e.name))
            .length;
      }
    }

    // 2) Compute totals
    final defaultIds = profile.customMealSlots.where((s) => s['isDefault'] == true).map((s) => s['id'] as String).toSet();
    final loggedIds = mealLog.customSlots.keys.toSet();
    final customLoggedCount = loggedIds.difference(defaultIds).length;
    final totalMealsTarget = defaultIds.length + customLoggedCount;
    
    final List<String> loggedEmojis = [];
    for (final slotId in loggedIds) {
      final log = mealLog.customSlots[slotId];
      if (log != null && (log.items.isNotEmpty || log.photoPath != null || log.totalCalories > 0)) {
        if (log.emoji != null) {
          loggedEmojis.add(log.emoji!);
        } else {
          final profileSlot = profile.customMealSlots.firstWhere((s) => s['id'] == slotId, orElse: () => {});
          if (profileSlot.isNotEmpty) loggedEmojis.add(profileSlot['emoji'] as String);
        }
      }
    }
    final emojiPrefix = loggedEmojis.isNotEmpty ? '${loggedEmojis.join(' ')} · ' : '';

    final completedMeals = mealLog.loggedSlotsCount;
    final totalHabitsTarget = applicableHabits.length;
    final completedHabits = applicableHabits.where((h) => isHabitCompleted(h, habitCompletions, dailyLog)).length;

    final totalThings = totalMealsTarget + totalHabitsTarget + (isRestDay ? 0 : 1);
    final totalDone = completedMeals + completedHabits + (isRestDay ? 0 : (workoutDayDone ? 1 : 0));

    // 3) Status pill logic
    String statusText = "Nothing logged";
    Color statusColor = context.colors.textMedium;
    if (totalDone == 0) {
      if (isRestDay) statusText = "Rest day / Nothing logged";
    } else if (totalDone >= (totalThings * 0.75).round()) {
      statusText = "Great day";
      statusColor = context.colors.green;
    } else {
      statusText = "Partial";
      statusColor = Colors.amber.shade700;
    }

    final missedHabits = applicableHabits
        .where((h) => !isHabitCompleted(h, habitCompletions, dailyLog))
        .map((h) => h.name)
        .join(', ');

    Habit? waterHabit;
    try {
      waterHabit = allHabits.firstWhere((h) => h.id == 'water');
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: context.colors.lavender,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            SizedBox(height: 12),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, dd MMM').format(date),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$totalDone of $totalThings things completed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textLight,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Rows
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Workout Row
                  _SummaryRow(
                    icon: Icons.fitness_center_rounded,
                    color: context.colors.primary,
                    title: workoutDayName,
                    subtitle: isRestDay 
                        ? 'Recovery day' 
                        : '$completedExercises/$totalExercises exercises done',
                    isDone: workoutDayDone,
                    onTap: () {
                      if (isRestDay || currentWorkoutDayId == null) return;
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home/workout/$currentWorkoutDayId');
                    },
                  ),
                  SizedBox(height: 12),

                  // Meals Row
                  _SummaryRow(
                    icon: Icons.restaurant_rounded,
                    color: context.colors.green,
                    title: '$emojiPrefix$completedMeals/$totalMealsTarget logged · ${mealLog.totalCalories} / ${profile.targetCalories} kcal',
                    subtitle: 'P: ${mealLog.totalProtein}g   C: ${mealLog.totalCarbs}g   F: ${mealLog.totalFat}g',
                    isDone: completedMeals == totalMealsTarget,
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home/meals');
                    },
                  ),
                  SizedBox(height: 12),

                  // Habits Row
                  _SummaryRow(
                    icon: Icons.checklist_rounded,
                    color: context.colors.primary,
                    title: 'Habits ($completedHabits/$totalHabitsTarget)',
                    subtitle: missedHabits.isNotEmpty ? 'Missed: $missedHabits' : 'All habits completed!',
                    isDone: completedHabits == totalHabitsTarget,
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home');
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Metrics 2x2 Grid
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.directions_walk_rounded,
                      label: 'Steps',
                      value: '${dailyLog.steps ?? 0}',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: dailyLog.sleepHours != null ? '${dailyLog.sleepHours}h' : '—',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.monitor_weight_rounded,
                      label: 'Weight',
                      value: dailyLog.weight != null ? '${dailyLog.weight} kg' : '—',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.water_drop_rounded,
                      label: 'Water',
                      value: waterHabit == null
                          ? '—'
                          : (isHabitCompleted(waterHabit, habitCompletions, dailyLog)
                              ? 'Done · ${waterHabit.target == waterHabit.target.roundToDouble() ? waterHabit.target.toInt() : waterHabit.target} ${waterHabit.unit.isNotEmpty ? waterHabit.unit : 'L'}'
                              : 'Goal ${waterHabit.target == waterHabit.target.roundToDouble() ? waterHabit.target.toInt() : waterHabit.target} ${waterHabit.unit.isNotEmpty ? waterHabit.unit : 'L'}'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Action Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).state = date;
                    final parentContext = rootNavigatorKey.currentContext!;
                    Navigator.of(context).pop();
                    parentContext.go('/home');
                  },
                  child: Text(
                    'Open full day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDone;
  final VoidCallback onTap;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isDone)
              Icon(Icons.check_circle_rounded, color: context.colors.green, size: 24)
            else
              Icon(Icons.chevron_right_rounded, color: context.colors.textLight, size: 24),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textLight,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../models/habit.dart';
import '../../../utils/workout_completion.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import 'past_day_summary_sheet.dart';
import 'daily_score_sheet.dart';

/// Activity flags for each day in a week (keyed by yyyy-MM-dd).
/// Rebuilds when selected-day logs/habits/meals or exercise logs change, then
/// re-reads Hive for all 7 days so dots stay correct for non-selected dates.
final calendarWeekActivityProvider =
    Provider.family<Map<String, bool>, String>((ref, weekStartStr) {
  ref.watch(dailyLogProvider);
  ref.watch(habitCompletionsProvider);
  ref.watch(dailyMealLogProvider);
  ref.watch(exerciseLogsUpdateProvider);

  final weekStart = DateTime.parse(weekStartStr);
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final mealRepo = ref.watch(mealRepoProvider);
  final habitRepo = ref.watch(habitRepoProvider);
  final habits = habitRepo.getHabits();

  final result = <String, bool>{};
  for (var i = 0; i < 7; i++) {
    final date = weekStart.add(Duration(days: i));
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final hasActivity = dailyLogRepo.hasActivityOnDate(dateStr);
    final mealLog = mealRepo.getDailyLog(dateStr);
    final habitCompletions = habitRepo.getCompletions(dateStr);
    final dailyLog = dailyLogRepo.getOrCreate(dateStr);

    final applicableHabits = habits.where((h) {
      final habitDate =
          DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      final sDate = DateTime(date.year, date.month, date.day);
      return !habitDate.isAfter(sDate);
    }).toList();

    final completedHabits = applicableHabits
        .where((h) => isHabitCompleted(h, habitCompletions, dailyLog))
        .length;

    result[dateStr] =
        hasActivity || mealLog.loggedSlotsCount > 0 || completedHabits > 0;
  }
  return result;
});

class WeekCalendarStrip extends ConsumerStatefulWidget {
  const WeekCalendarStrip({super.key});

  @override
  ConsumerState<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends ConsumerState<WeekCalendarStrip> {
  late PageController _pageController;
  final int _basePage = 10000;

  @override
  void initState() {
    super.initState();
    // Use the initial week offset if any
    final initialOffset = ref.read(weekOffsetProvider);
    _pageController = PageController(initialPage: _basePage + initialOffset);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    ref.listen<int>(weekOffsetProvider, (prev, next) {
      if (_pageController.hasClients) {
        final targetPage = _basePage + next;
        if (_pageController.page?.round() != targetPage) {
          _pageController.animateToPage(
            targetPage,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return SurfaceCard(
      margin: EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: Column(
        children: [
          // Date header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_isSameDay(selectedDate, today)) ...[
                GestureDetector(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(weekOffsetProvider.notifier).state = 0;
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Text(
                DateFormat('EEE, d').format(selectedDate),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM').format(selectedDate).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textLight,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy').format(selectedDate),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textLight,
                    ),
                  ),
                ],
              ),
              Spacer(),
              const _DailyScoreBadge(),
              SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: context.colors.primary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(selectedDateProvider.notifier).state = picked;
                    // Calculate week offset between today and picked date
                    final pickedWeekStart =
                        picked.subtract(Duration(days: picked.weekday - 1));
                    final todayWeekStart =
                        today.subtract(Duration(days: today.weekday - 1));
                    final diffDays =
                        pickedWeekStart.difference(todayWeekStart).inDays;
                    final weekOffset = (diffDays / 7).round();
                    ref.read(weekOffsetProvider.notifier).state = weekOffset;
                  }
                },
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: context.colors.textLight,
                  size: 24,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Week day circles
          SizedBox(
            height: 70,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) {
                ref.read(weekOffsetProvider.notifier).state = idx - _basePage;
              },
              itemBuilder: (context, index) {
                final weekOffset = index - _basePage;
                final weekStart = today
                    .subtract(Duration(days: today.weekday - 1))
                    .add(Duration(days: weekOffset * 7));

                return _WeekDaysRow(
                  weekStart: weekStart,
                  today: today,
                  selectedDate: selectedDate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekDaysRow extends ConsumerWidget {
  const _WeekDaysRow({
    required this.weekStart,
    required this.today,
    required this.selectedDate,
  });

  final DateTime weekStart;
  final DateTime today;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final activityByDate = ref.watch(calendarWeekActivityProvider(weekStartStr));
    final weekDays =
        List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((day) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        return _DayCircle(
          date: day,
          isSelected: _isSameDay(day, selectedDate),
          isToday: _isSameDay(day, today),
          isFuture: day.isAfter(today),
          isComplete: activityByDate[dateStr] ?? false,
        );
      }).toList(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayCircle extends ConsumerWidget {
  const _DayCircle({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isFuture,
    required this.isComplete,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isFuture;
  final bool isComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayName = DateFormat('E').format(date).substring(0, 3);
    final dayNum = date.day.toString();

    // Planned rest: no activity dot ΓÇö green/red would misread rest as success/failure.
    final plan = ref.watch(workoutPlanProvider);
    final isRestDay = plan != null
        ? WorkoutCompletion.isRestDay(
            WorkoutCompletion.resolveWorkoutDay(plan, date),
            date,
          )
        : date.weekday == DateTime.sunday;

    final muted = context.colors.border;
    Color? dotColor;
    if (isRestDay) {
      dotColor = null;
    } else if (isFuture) {
      dotColor = muted;
    } else if (isToday) {
      dotColor = isComplete ? context.colors.green : context.colors.red;
    } else {
      dotColor = isComplete ? context.colors.green : muted;
    }

    return GestureDetector(
      onTap: () {
        if (isFuture || isToday) {
          ref.read(selectedDateProvider.notifier).state = date;
        } else {
          showAppBottomSheet(
            context: context,
            builder: (_) => PastDaySummarySheet(date: date),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color:
                  isSelected ? context.colors.primary : context.colors.textLight,
            ),
          ),
          SizedBox(height: 6),
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? context.colors.primary : Colors.transparent,
            ),
            child: Center(
              child: Text(
                dayNum,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? context.colors.white
                      : (isToday
                          ? context.colors.primary
                          : context.colors.textDark),
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          // Activity dot (hidden on rest days)
          SizedBox(
            width: 5,
            height: 5,
            child: dotColor == null
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DailyScoreBadge extends ConsumerStatefulWidget {
  const _DailyScoreBadge();

  @override
  ConsumerState<_DailyScoreBadge> createState() => _DailyScoreBadgeState();
}

class _DailyScoreBadgeState extends ConsumerState<_DailyScoreBadge> {
  @override
  Widget build(BuildContext context) {
    final scoreData = ref.watch(dailyScoreProvider);

    final score = scoreData.totalScore;
    final isFuture = scoreData.isFutureDate;
    final displayScore = isFuture ? '--' : score.toString();

    Color iconColor;
    Color textColor;
    List<Color>? gradientColors;
    Color borderColor;
    IconData iconData = Icons.local_fire_department_rounded;

    if (isFuture) {
      iconColor = context.colors.textLight;
      textColor = context.colors.textLight;
      gradientColors = null;
      borderColor = Colors.transparent;
    } else if (score == 0) {
      iconColor = context.colors.textLight;
      textColor = context.colors.textDark.withValues(alpha: 0.7);
      gradientColors = [context.colors.border.withValues(alpha: 0.3), context.colors.border.withValues(alpha: 0.1)];
      borderColor = context.colors.border;
    } else if (score < 50) {
      // Starting to warm up
      iconColor = context.colors.orange;
      textColor = context.colors.textDark;
      gradientColors = [context.colors.orange.withValues(alpha: 0.15), context.colors.orange.withValues(alpha: 0.05)];
      borderColor = context.colors.orange.withValues(alpha: 0.3);
    } else if (score < 90) {
      // Getting hot!
      iconColor = context.colors.red;
      textColor = context.colors.textDark;
      gradientColors = [context.colors.red.withValues(alpha: 0.15), context.colors.red.withValues(alpha: 0.05)];
      borderColor = context.colors.red.withValues(alpha: 0.3);
    } else {
      // Top Tier Bodamma Flame!
      iconColor = context.colors.primary;
      textColor = context.colors.primary;
      gradientColors = [context.colors.primary.withValues(alpha: 0.25), context.colors.primary.withValues(alpha: 0.05)];
      borderColor = context.colors.primary.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              showAppBottomSheet(
                context: context,
                builder: (ctx) => const DailyScoreSheet(),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: gradientColors == null
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: gradientColors == null ? context.colors.border.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              displayScore,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import '../../services/health_connect_service.dart';
import '../../services/screen_time_service.dart';
import '../../models/habit.dart';
import '../../utils/workout_completion.dart';
import '../../widgets/section_header.dart';
import '../../widgets/surface_card.dart';
import '../profile/manage_habits_screen.dart';
import 'widgets/week_calendar_strip.dart';
import 'widgets/meals_card.dart';
import 'widgets/habits_card.dart';
import 'widgets/daily_progress_grid.dart';
import 'widgets/coach_notes_card.dart';
import 'widgets/day_complete_sheet.dart';

import 'package:confetti/confetti.dart';
import '../../providers/gamification_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    // Initial sync when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSteps(isManualRefresh: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSteps(isManualRefresh: false);
    }
  }

  Future<void> _syncSteps({bool isManualRefresh = false}) async {
    final hcService = ref.read(healthConnectServiceProvider);
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final habitRepo = ref.read(habitRepoProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // Refresh local state immediately (covers cached Hive values on cold start)
    ref.invalidate(dailyLogProvider);
    ref.invalidate(habitCompletionsProvider);

    // Coach note is date-scoped — only auto-refresh when viewing today
    final selectedDate = ref.read(dateStringProvider);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (selectedDate == todayStr) {
      ref.read(coachNoteProvider.notifier).fetchNote(force: isManualRefresh);
    }

    // Sync Screen Time
    if (ref.read(profileProvider).screenTimeEnabled) {
      final screenTimeMins = await ref.read(screenTimeServiceProvider).getScreenTimeForToday();
      if (screenTimeMins > 0) {
        await dailyLogRepo.updateScreenTime(todayStr, screenTimeMins);
      }
    }

    final available = await hcService.isAvailable();
    if (!available) return;

    final now = DateTime.now();
    final lastSyncStr = prefs.getString('last_hc_sync_time');
    final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
    final everConnected = prefs.getBool('hc_connected') ?? false;

    // Always refresh TODAY on open/resume.
    // Do NOT gate on hasPermissions — it often returns false after the app is killed
    // even when Health Connect access was already granted.
    final todaySteps = await hcService.syncTodayAndAutoCompleteHabit(
      dailyLogRepo,
      habitRepo,
    );

    if (todaySteps != null) {
      await prefs.setBool('hc_connected', true);
      ref.read(stepsSourceProvider.notifier).state = StepsSource.healthConnect;
    } else if (!everConnected) {
      // First-run: Steps card will show the Sync CTA
      ref.invalidate(dailyLogProvider);
      ref.invalidate(habitCompletionsProvider);
      return;
    }

    // Heavier historical sync — manual pull or every 15 minutes
    final shouldFullSync = isManualRefresh ||
        lastSync == null ||
        now.difference(lastSync).inMinutes >= 15;

    if (shouldFullSync) {
      await hcService.syncLast7Days(dailyLogRepo, habitRepo);
      if (!hcService.isBackfillDone) {
        await hcService.backfillLast90Days(dailyLogRepo, habitRepo);
      }
      await prefs.setString('last_hc_sync_time', now.toIso8601String());
    }

    ref.invalidate(dailyLogProvider);
    ref.invalidate(habitCompletionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutPlanProvider);

    // One calm day-complete sheet when primary buckets fill (today only).
    ref.listen<DailyScore>(dailyScoreProvider, (prev, next) {
      if (next.isPrimaryComplete &&
          (prev == null || !prev.isPrimaryComplete)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) maybeShowDayCompleteSheet(context, ref);
        });
      }
    });

    ref.listen<int>(stepsStreakProvider, (prev, next) {
      if (next > 5 && (prev == null || prev <= 5)) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Woohoo! You hit your steps goal for $next days in a row! 💃'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colors.green,
          ),
        );
      }
    });

    ref.listen<int>(mealStreakProvider, (prev, next) {
      if (next == 3 && (prev == null || prev < 3)) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Amazing! You\'ve logged your meals for 3 days in a row! 🌻'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colors.green,
          ),
        );
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.colors.scaffoldBg,
          body: SafeArea(
            child: RefreshIndicator(
              color: context.colors.primary,
              onRefresh: () => _syncSteps(isManualRefresh: true),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),


                // 1. Greeting
                const _HomeGreeting(),
                const SizedBox(height: 24),

                // 2. Week calendar + score
                const WeekCalendarStrip(),
                const SizedBox(height: 24),

                // 3. Workout (primary daily action)
                if (plan != null && plan.days.isNotEmpty) ...[
                  _WorkoutsSection(plan: plan),
                  const SizedBox(height: 24),
                ],

                // 4. Habits
                SectionHeader(
                  'HABITS',
                  trailing: const _HabitsEditButton(),
                  countLabel: const _HabitsCountLabel(),
                ),
                const SizedBox(height: 12),
                const HabitsCard(),
                const SizedBox(height: 24),

                // 5. Meals
                const SectionHeader('MEALS'),
                const SizedBox(height: 12),
                const MealsCard(),
                const SizedBox(height: 24),

                // 6. Daily progress metrics
                const SectionHeader(
                  'DAILY PROGRESS',
                  icon: Icons.show_chart_rounded,
                ),
                const SizedBox(height: 12),
                const DailyProgressGrid(),
                const SizedBox(height: 16),

                // Weekly summary soft link
                const _WeeklySummaryLink(),
                const SizedBox(height: 24),

                // 7. Coach notes last (below fold)
                const CoachNotesCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }
}

class _HomeGreeting extends ConsumerWidget {
  const _HomeGreeting();

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider.select((p) => p.name)).trim();
    final selected = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(selected.year, selected.month, selected.day);
    final isToday = selectedDay == today;

    final title = name.isEmpty ? _timeGreeting() : '${_timeGreeting()}, $name';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
              height: 1.15,
            ),
          ),
          if (!isToday) ...[
            const SizedBox(height: 4),
            Text(
              'Looking at ${DateFormat('EEE, MMM d').format(selected)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklySummaryLink extends StatelessWidget {
  const _WeeklySummaryLink();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/progress/weekly-summary'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: context.colors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "This week's summary",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitsCountLabel extends ConsumerWidget {
  const _HabitsCountLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final completions = ref.watch(habitCompletionsProvider);
    final dailyLog = ref.watch(dailyLogProvider);
    final completedCount =
        habits.where((h) => isHabitCompleted(h, completions, dailyLog)).length;

    return Text(
      '($completedCount/${habits.length})',
      style: TextStyle(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: context.colors.primary,
        fontSize: 13,
      ),
    );
  }
}

class _HabitsEditButton extends StatelessWidget {
  const _HabitsEditButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => ManageHabitsScreen()),
        );
      },
      child: Icon(Icons.edit_rounded, color: context.colors.primary, size: 18),
    );
  }
}

class _WorkoutsSection extends ConsumerWidget {
  const _WorkoutsSection({required this.plan});

  final dynamic plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutPlan = ref.watch(workoutPlanProvider);
    final phaseProgress = ref.watch(phaseProgressProvider);
    if (workoutPlan == null || workoutPlan.days.isEmpty) return SizedBox();

    final dateStr = ref.watch(dateStringProvider);
    
    final selectedDate = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = selectedDate.isAfter(today);

    final day = WorkoutCompletion.resolveWorkoutDay(workoutPlan, selectedDate);
    final isRest = WorkoutCompletion.isRestDay(day, selectedDate);
    
    final logRepo = ref.watch(exerciseLogRepoProvider);
    ref.watch(exerciseLogsUpdateProvider); // Rebuild when logs are saved
    final dailyLog = ref.watch(dailyLogProvider);
    final isWholeDayCompleted = WorkoutCompletion.isDayWorkoutDoneWithRepo(
      date: dateStr,
      day: day,
      dateTime: selectedDate,
      repo: logRepo,
      dailyLog: dailyLog,
    );
    
    List<Widget> cards = [];
    int completedCount = 0;
    
    if (isRest) {
      cards.add(_buildCard(
        context,
        title: 'Rest Day',
        subtitle: 'Recovery day — you\'re all set. Rest counts as complete.',
        isCompleted: isWholeDayCompleted, 
        isFuture: isFuture,
        isRest: true,
      ));
      if (isWholeDayCompleted) completedCount = 1;
    } else {
      for (int i = 0; i < day.sections.length; i++) {
        final sec = day.sections[i];
        
        final isCompleted = WorkoutCompletion.isSectionCompleteWithRepo(
          dateStr,
          sec,
          logRepo,
        );
        if (isCompleted) completedCount++;
        
        String title = (i == 0) ? day.dayId : sec.title;
        if (sec.title.toLowerCase().contains('cooldown') || sec.title.toLowerCase().contains('cool down')) {
          title = 'Cool down';
        }
        
        String subtitle = (i == 0) ? 'Complete your scheduled workout' : '${sec.exercises.length} exercises';
        
        cards.add(Padding(
          padding: EdgeInsets.only(top: 8),
          child: _buildCard(
            context,
            title: title,
            subtitle: subtitle,
            isCompleted: isCompleted,
            isFuture: isFuture,
            isRest: false,
            heroTag: 'workout-${day.dayId}-section-$i',
            onTap: () => context.go('/home/workout/${day.dayId}?section=$i'),
          ),
        ));
      }
    }
    
    final total = isRest ? 1 : day.sections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'WORKOUTS ($completedCount/$total)',
          trailing: phaseProgress.isPhaseActive
              ? Row(
                  children: [
                    Text(
                      'Week ${phaseProgress.currentWeek} of ${phaseProgress.totalWeeks}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: (phaseProgress.currentWeek - 1) /
                            phaseProgress.totalWeeks,
                        strokeWidth: 2,
                        backgroundColor:
                            context.colors.primary.withValues(alpha: 0.2),
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(children: cards),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isFuture,
    required bool isRest,
    String? heroTag,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        onTap: isFuture ? null : onTap,
        border: isCompleted
            ? Border.all(
                color: context.colors.green.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heroTag != null)
                    Hero(
                      tag: heroTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.colors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.colors.textMedium,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            if (isCompleted)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: context.colors.green,
                  size: 20,
                ),
              )
            else if (isRest)
              Icon(
                Icons.self_improvement_rounded,
                color: context.colors.textLight,
                size: 26,
              )
            else
              Icon(
                Icons.fitness_center_outlined,
                color: context.colors.textDark,
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}

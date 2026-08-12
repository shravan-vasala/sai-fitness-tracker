import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan.dart';
import 'widgets/exercise_card.dart';
import 'widgets/rest_timer_label.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.dayId,
    this.sectionIndex,
  });

  final String dayId;
  /// null = show all sections; 0+ = show that specific section only
  final int? sectionIndex;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// When non-null, only show that section. When null, show all.
  int? _activeSectionIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeSectionIndex = widget.sectionIndex;
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutPlanProvider);
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Workout')),
        body: Center(child: Text('No workout plan found')),
      );
    }

    WorkoutDay? day;
    for (final d in plan.days) {
      if (d.dayId == widget.dayId) {
        day = d;
        break;
      }
    }

    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Workout')),
        body: Center(child: Text('Workout day not found')),
      );
    }

    final workoutDay = day;

    final logRepo = ref.watch(exerciseLogRepoProvider);
    final dateStr = ref.watch(dateStringProvider);
    ref.watch(exerciseLogsUpdateProvider); // Trigger rebuild on log save
    
    final totalExercises = workoutDay.sections
        .fold<int>(0, (sum, s) => sum + s.exercises.length);
    final completedExercises = workoutDay.sections
        .fold<int>(0, (sum, s) => sum + s.exercises.where((e) => logRepo.hasLog(dateStr, e.name)).length);
    
    final isFinished =
        ref.watch(workoutRepoProvider).isWorkoutFinished(dateStr, widget.dayId);

    // Determine which sections to display
    final bool isFiltered = _activeSectionIndex != null &&
        _activeSectionIndex! >= 0 &&
        _activeSectionIndex! < workoutDay.sections.length;
    final sectionsToShow = isFiltered
        ? [workoutDay.sections[_activeSectionIndex!]]
        : workoutDay.sections;

    // Title: use section name when filtered, day label when showing all
    final String appBarTitle = isFiltered
        ? workoutDay.sections[_activeSectionIndex!].title
        : workoutDay.label ?? workoutDay.dayId;

    // Progress counts for current view
    final viewExercises = isFiltered
        ? workoutDay.sections[_activeSectionIndex!].exercises.length
        : totalExercises;
    final viewCompleted = isFiltered
        ? workoutDay.sections[_activeSectionIndex!].exercises
            .where((e) => logRepo.hasLog(dateStr, e.name))
            .length
        : completedExercises;

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.sectionIndex != null)
                          Hero(
                            tag: 'workout-${widget.dayId}-section-${widget.sectionIndex}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                appBarTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textDark,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            appBarTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textDark,
                            ),
                          ),
                        Text(
                          '$viewCompleted/$viewExercises exercises done',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFinished)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colors.greenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: context.colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // ── Progress bar (always total day progress) ─────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:
                      totalExercises > 0 ? completedExercises / totalExercises : 0,
                  backgroundColor: context.colors.primary.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.colors.green),
                  minHeight: 6,
                ),
              ),
            ),
            SizedBox(height: 4),
            if (totalExercises > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Day total: $completedExercises/$totalExercises',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12),

            // ── "Show all sections" banner when filtered ─────────────────
            if (isFiltered)
              GestureDetector(
                onTap: () => setState(() => _activeSectionIndex = null),
                child: Container(
                  margin: EdgeInsets.fromLTRB(20, 0, 20, 10),
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.lavenderCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grid_view_rounded,
                          color: context.colors.primary, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Showing: ${workoutDay.sections[_activeSectionIndex!].title}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Show all →',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Sections list ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: sectionsToShow.length,
                itemBuilder: (context, listIndex) {
                  // Map back to original section index for consistency
                  final sectionIndex = isFiltered
                      ? _activeSectionIndex!
                      : listIndex;
                  final section = sectionsToShow[listIndex];
                  return _SectionWidget(
                    section: section,
                    sectionIndex: sectionIndex,
                    dayId: widget.dayId,
                  );
                },
              ),
            ),

            // ── Finish Workout Button ─────────────────────────────────────
            if (!isFinished)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: context.colors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _finishWorkout(context, ref, widget.dayId,
                        completedExercises, totalExercises),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            color: context.colors.onPrimary, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Finish Workout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _finishWorkout(BuildContext context, WidgetRef ref, String dayId,
      int completed, int total) {
    if (completed < total) {
      if (completed == 0) {
        _showSkipConfirmation(context, ref, dayId);
      } else {
        _showPartialConfirmation(context, ref, dayId, completed, total);
      }
    } else {
      _executeFinish(context, ref, dayId);
    }
  }

  void _showPartialConfirmation(BuildContext context, WidgetRef ref,
      String dayId, int completed, int total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Finish early?'),
        content:
            Text('Only $completed of $total exercises done — finish anyway?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeFinish(context, ref, dayId);
            },
            child: Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _showSkipConfirmation(
      BuildContext context, WidgetRef ref, String dayId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Skip workout?'),
        content: Text(
            'Nothing checked — mark this workout as skipped instead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _persistWorkoutFinished(ref, dayId);
              context.go('/home');
            },
            child: Text('Skip Workout'),
          ),
        ],
      ),
    );
  }

  void _persistWorkoutFinished(WidgetRef ref, String dayId) {
    final dateStr = ref.read(dateStringProvider);
    ref.read(workoutRepoProvider).finishWorkout(dateStr, dayId);
    ref.read(dailyLogProvider.notifier).markWorkoutCompleted(dayId);
  }

  void _executeFinish(BuildContext context, WidgetRef ref, String dayId) {
    _persistWorkoutFinished(ref, dayId);
    HapticFeedback.mediumImpact();

    final name = ref.read(profileProvider).name.trim();
    final title = name.isEmpty ? 'Workout complete!' : 'Nice work, $name!';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: context.colors.card,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: context.colors.green,
                  size: 40,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Session saved. Head home to finish habits and meals if you have any left.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Widget ───────────────────────────────────────────────────────────

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({
    required this.section,
    required this.sectionIndex,
    required this.dayId,
  });

  final WorkoutSection section;
  final int sectionIndex;
  final String dayId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.lavenderCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky-style section header
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  section.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                Spacer(),
                Text(
                  '${section.exercises.length} exercises',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          // Exercises
          ...List.generate(section.exercises.length * 2 - 1, (index) {
            if (index.isOdd) {
              final exerciseIndex = index ~/ 2;
              final exercise = section.exercises[exerciseIndex];
              if (exercise.restSecondsAfterSet > 0) {
                return RestTimerLabel(
                  seconds: exercise.restSecondsAfterSet,
                  exerciseName: exercise.name,
                );
              }
              return SizedBox(height: 4);
            }
            final exerciseIndex = index ~/ 2;
            final exercise = section.exercises[exerciseIndex];
            return ExerciseCard(
              exercise: exercise,
              dayId: dayId,
            );
          }),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

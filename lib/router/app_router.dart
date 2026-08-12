import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/meal_detail_screen.dart';
import '../screens/home/body_stats_screen.dart';
import '../screens/home/physique_pictures_screen.dart';
import '../screens/workout/workout_screen.dart';
import '../screens/workout/youtube_player_screen.dart';
import '../screens/workout/exercise_progress_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/progress/weekly_summary_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/manage_plans_screen.dart';
import '../screens/profile/backup_restore_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/reminders_screen.dart';
import '../theme/app_colors.dart';
import '../theme/layout_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../providers/reminders_provider.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _progressNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'progress');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(onboardingCompletedProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: ref.watch(routerNotifierProvider),
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Page Not Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textDark)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final isCompleted = ref.read(onboardingCompletedProvider);
      
      if (!isCompleted && state.uri.path != '/onboarding') {
        return '/onboarding';
      }
      
      if (isCompleted && state.uri.path == '/onboarding') {
        return '/home';
      }
      
      if (state.uri.path == '/' || state.uri.path.isEmpty) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'meals',
                  builder: (context, state) => const MealDetailScreen(),
                ),
                GoRoute(
                  path: 'body-stats',
                  builder: (context, state) => const BodyStatsScreen(),
                ),
                GoRoute(
                  path: 'physique-pictures',
                  builder: (context, state) => const PhysiquePicturesScreen(),
                ),
                GoRoute(
                  path: 'workout/:dayId',
                  builder: (context, state) {
                    final dayId = state.pathParameters['dayId']!;
                    final sectionParam = state.uri.queryParameters['section'];
                    final sectionIndex = sectionParam != null
                        ? int.tryParse(sectionParam)
                        : null;
                    return WorkoutScreen(dayId: dayId, sectionIndex: sectionIndex);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _progressNavigatorKey,
          routes: [
            GoRoute(
              path: '/progress',
              builder: (context, state) {
                final metricStr = state.uri.queryParameters['metric'];
                MetricType? metric;
                if (metricStr != null) {
                  switch (metricStr) {
                    case 'weight':
                      metric = MetricType.weight;
                      break;
                    case 'steps':
                      metric = MetricType.steps;
                      break;
                    case 'sleep':
                      metric = MetricType.sleep;
                      break;
                    case 'bmi':
                      metric = MetricType.bmi;
                      break;
                    case 'bodyFat':
                      metric = MetricType.bodyFat;
                      break;
                    case 'calories':
                      metric = MetricType.calories;
                      break;
                    case 'protein':
                    case 'macros': // legacy deep link
                      metric = MetricType.protein;
                      break;
                  }
                }
                return ProgressScreen(initialMetric: metric);
              },
              routes: [
                GoRoute(
                  path: 'weekly-summary',
                  builder: (context, state) => const WeeklySummaryScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _profileNavigatorKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [

                GoRoute(
                  path: 'manage-plans',
                  builder: (context, state) => const ManagePlansScreen(),
                ),
                GoRoute(
                  path: 'backup-restore',
                  builder: (context, state) => const BackupRestoreScreen(),
                ),
                GoRoute(
                  path: 'reminders',
                  builder: (context, state) => const RemindersScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Full-screen routes (outside bottom nav)
    GoRoute(
      path: '/youtube-player',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final videoId = state.uri.queryParameters['videoId'] ?? '';
        final title = state.uri.queryParameters['title'] ?? '';
        final subtitle = state.uri.queryParameters['subtitle'] ?? '';
        final reps = state.uri.queryParameters['reps'] ?? '';
        return YoutubePlayerScreen(videoId: videoId, title: title, subtitle: subtitle, reps: reps);
      },
    ),
    GoRoute(
      path: '/exercise-progress',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final exerciseName = state.uri.queryParameters['name'] ?? '';
        return ExerciseProgressScreen(exerciseName: exerciseName);
      },
    ),
  ],
);
});

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(restTimerProvider);
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0, initialLocation: false);
        }
      },
      child: Scaffold(
      // Floating pill nav paints over the body; inflate MediaQuery padding so
        // SafeArea / scroll views leave room and content isn't trapped under it.
        extendBody: true,
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.paddingOf(context).copyWith(
              bottom: MediaQuery.paddingOf(context).bottom + 
                      kFloatingNavClearance + 
                      (timerState.isActive ? 76.0 : 0.0),
            ),
          ),
          child: Stack(
          children: [
            navigationShell,
            if (timerState.isActive)
              Positioned(
                bottom: kFloatingNavClearance,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.orange.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        timerState.isPaused ? Icons.pause_circle_filled : Icons.timer,
                        color: context.colors.onPrimary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timerState.exerciseName != null
                                  ? 'Resting for ${timerState.exerciseName}'
                                  : 'Resting',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${timerState.remainingSeconds ~/ 60}:${(timerState.remainingSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TimerControlButton(
                            label: '+15s',
                            onTap: () => ref.read(restTimerProvider.notifier).addSeconds(15),
                          ),
                          SizedBox(width: 8),
                          _TimerControlButton(
                            label: '+30s',
                            onTap: () => ref.read(restTimerProvider.notifier).addSeconds(30),
                          ),
                          SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              timerState.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              color: context.colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () {
                              if (timerState.isPaused) {
                                ref.read(restTimerProvider.notifier).resumeTimer();
                              } else {
                                ref.read(restTimerProvider.notifier).pauseTimer();
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: context.colors.white),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () {
                              ref.read(restTimerProvider.notifier).stopTimer();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 12),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: context.colors.textDark.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => navigationShell.goBranch(0),
                ),
                _NavItem(
                  icon: Icons.show_chart_outlined,
                  activeIcon: Icons.show_chart_rounded,
                  label: 'Progress',
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => navigationShell.goBranch(1),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(2),
                ),
              ],
          ),
        ),
      ),
    ));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label tab, ${isSelected ? 'selected' : 'unselected'}',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          constraints: BoxConstraints(minHeight: 48, minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? context.colors.onPrimary : context.colors.textLight,
              size: 24,
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _TimerControlButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimerControlButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: context.colors.card,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/hive_adapters.dart';
import 'repositories/workout_repository.dart';
import 'repositories/meal_repository.dart';
import 'repositories/daily_log_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/body_stats_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/exercise_log_repository.dart';
import 'repositories/coach_note_repository.dart';
import 'services/health_connect_service.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';
import 'services/schema_migration_service.dart';
import 'providers/app_providers.dart';
import 'providers/reminders_provider.dart';
import 'router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();
  registerHiveAdapters();
  
  final prefs = await SharedPreferences.getInstance();
  await SchemaMigrationService.runStartupMigrations(prefs);

  // Initialize all repositories
  final workoutRepo = WorkoutRepository();
  final mealRepo = MealRepository();
  final dailyLogRepo = DailyLogRepository();
  final habitRepo = HabitRepository();
  final bodyStatsRepo = BodyStatsRepository();
  final mediaRepo = MediaRepository();
  final profileRepo = ProfileRepository();
  final exerciseLogRepo = ExerciseLogRepository();
  final coachNoteRepo = CoachNoteRepository();
  final healthConnectService = HealthConnectService();

  await Future.wait([
    workoutRepo.init(),
    mealRepo.init(),
    dailyLogRepo.init(),
    habitRepo.init(),
    bodyStatsRepo.init(),
    mediaRepo.init(),
    profileRepo.init(),
    exerciseLogRepo.init(),
    coachNoteRepo.init(),
    healthConnectService.init(),
    NotificationService().init(),
  ]);

  final authService = AuthService();
  final firestoreSyncService = FirestoreSyncService(authService);
  
  workoutRepo.attachSync(firestoreSyncService);
  mealRepo.attachSync(firestoreSyncService);
  dailyLogRepo.attachSync(firestoreSyncService);
  habitRepo.attachSync(firestoreSyncService);
  bodyStatsRepo.attachSync(firestoreSyncService);
  profileRepo.attachSync(firestoreSyncService);
  exerciseLogRepo.attachSync(firestoreSyncService);
  coachNoteRepo.attachSync(firestoreSyncService);

  // Fetch global plans from Firebase (non-blocking) to merge with local seed data
  workoutRepo.fetchGlobalPlans();
  mealRepo.fetchGlobalPlans();
  
  // Fetch user-specific personal plans from Firebase (non-blocking)
  workoutRepo.fetchUserPlans();
  mealRepo.fetchUserPlans();
  
  // Run weekly auto-backup (non-blocking)
  BackupService().autoBackup();

  final initialGeminiKey = await profileRepo.getSecureGeminiKey();

  runApp(
    ProviderScope(
      overrides: [
        workoutRepoProvider.overrideWithValue(workoutRepo),
        mealRepoProvider.overrideWithValue(mealRepo),
        dailyLogRepoProvider.overrideWithValue(dailyLogRepo),
        habitRepoProvider.overrideWithValue(habitRepo),
        bodyStatsRepoProvider.overrideWithValue(bodyStatsRepo),
        mediaRepoProvider.overrideWithValue(mediaRepo),
        profileRepoProvider.overrideWithValue(profileRepo),
        exerciseLogRepoProvider.overrideWithValue(exerciseLogRepo),
        coachNoteRepoProvider.overrideWithValue(coachNoteRepo),
        healthConnectServiceProvider.overrideWithValue(healthConnectService),
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialGeminiKeyProvider.overrideWithValue(initialGeminiKey ?? ''),
      ],
      child: const TruFitApp(),
    ),
  );
}

class TruFitApp extends ConsumerStatefulWidget {
  const TruFitApp({super.key});

  @override
  ConsumerState<TruFitApp> createState() => _TruFitAppState();
}

class _TruFitAppState extends ConsumerState<TruFitApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications and sync them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).initializeNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sthira',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/providers/app_providers.dart';
import 'package:trufit_bodamma/providers/phase_progress_provider.dart';
import 'package:trufit_bodamma/repositories/daily_log_repository.dart';
import 'package:trufit_bodamma/repositories/profile_repository.dart';
import 'package:trufit_bodamma/repositories/workout_repository.dart';
import 'package:trufit_bodamma/repositories/exercise_log_repository.dart';
import '../helpers/test_hive_setup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  late ProfileRepository profileRepo;
  late DailyLogRepository dailyLogRepo;
  late WorkoutRepository workoutRepo;
  late ExerciseLogRepository exerciseLogRepo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    await setUpTestHive();

    profileRepo = ProfileRepository();
    await profileRepo.init();

    dailyLogRepo = DailyLogRepository();
    await dailyLogRepo.init();

    workoutRepo = WorkoutRepository();
    await workoutRepo.init();

    exerciseLogRepo = ExerciseLogRepository();
    await exerciseLogRepo.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  ProviderContainer _buildContainer(DateTime selected) {
    return ProviderContainer(
      overrides: [
        profileRepoProvider.overrideWithValue(profileRepo),
        dailyLogRepoProvider.overrideWithValue(dailyLogRepo),
        workoutRepoProvider.overrideWithValue(workoutRepo),
        exerciseLogRepoProvider.overrideWithValue(exerciseLogRepo),
        selectedDateProvider.overrideWith((ref) => selected),
      ],
    );
  }

  test('phaseProgressProvider week boundary calculation', () async {
    final profile = profileRepo.getProfile();
    final startDate = DateTime.now().subtract(const Duration(days: 7));
    await profileRepo.saveProfile(profile.copyWith(planStartDate: startDate));

    final today = DateTime.now();
    final testContainer = _buildContainer(
      DateTime(today.year, today.month, today.day),
    );

    final progress = testContainer.read(phaseProgressProvider);
    expect(progress.currentWeek, 2);
    expect(progress.isPhaseActive, true);
    testContainer.dispose();
  });

  test('phaseProgressProvider week 1 day 7 calculation', () async {
    final profile = profileRepo.getProfile();
    final startDate = DateTime.now().subtract(const Duration(days: 6));
    await profileRepo.saveProfile(profile.copyWith(planStartDate: startDate));

    final today = DateTime.now();
    final testContainer = _buildContainer(
      DateTime(today.year, today.month, today.day),
    );

    final progress = testContainer.read(phaseProgressProvider);
    expect(progress.currentWeek, 1);
    expect(progress.isPhaseActive, true);
    testContainer.dispose();
  });
}

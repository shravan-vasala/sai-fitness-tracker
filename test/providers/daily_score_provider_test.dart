import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/providers/app_providers.dart';
import 'package:trufit_bodamma/providers/daily_score_provider.dart';
import 'package:trufit_bodamma/repositories/daily_log_repository.dart';
import 'package:trufit_bodamma/repositories/exercise_log_repository.dart';
import 'package:trufit_bodamma/repositories/habit_repository.dart';
import 'package:trufit_bodamma/repositories/meal_repository.dart';
import 'package:trufit_bodamma/repositories/workout_repository.dart';
import 'package:trufit_bodamma/repositories/profile_repository.dart';
import 'package:trufit_bodamma/models/exercise_log.dart';
import 'package:trufit_bodamma/models/workout_plan.dart';
import 'package:trufit_bodamma/models/meal_plan.dart';
import 'package:trufit_bodamma/models/daily_meal_log.dart';
import 'dart:convert';
import '../helpers/test_hive_setup.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  late ProviderContainer container;
  late ExerciseLogRepository logRepo;
  late WorkoutRepository workoutRepo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    logRepo = ExerciseLogRepository();
    await logRepo.init();
    
    workoutRepo = WorkoutRepository();
    await workoutRepo.init();

    final habitRepo = HabitRepository();
    await habitRepo.init();

    final mealRepo = MealRepository();
    await mealRepo.init();

    final dailyRepo = DailyLogRepository();
    await dailyRepo.init();
    
    final profileRepo = ProfileRepository();
    await profileRepo.init();

    // Create a mock workout plan in the repo
    final mockPlan = WorkoutPlan(
      planName: 'Test Plan',
      days: [
        WorkoutDay(
          dayId: 'day_1',
          label: 'Monday',
          sections: [
            WorkoutSection(
              title: 'Main',
              exercises: [
                Exercise(name: 'Bench Press', reps: ['10', '10', '10'], restSecondsAfterSet: 60),
                Exercise(name: 'Squat', reps: ['10', '10', '10'], restSecondsAfterSet: 60),
              ]
            )
          ]
        )
      ]
    );
    // Overwrite the seeded beginner plan to ensure this one is returned as active
    await workoutRepo.savePlan('beginner_plan', mockPlan);

    container = ProviderContainer(
      overrides: [
        exerciseLogRepoProvider.overrideWithValue(logRepo),
        workoutRepoProvider.overrideWithValue(workoutRepo),
        habitRepoProvider.overrideWithValue(habitRepo),
        mealRepoProvider.overrideWithValue(mealRepo),
        dailyLogRepoProvider.overrideWithValue(dailyRepo),
        profileRepoProvider.overrideWithValue(profileRepo),
        selectedDateProvider.overrideWith((ref) => DateTime(2023, 10, 2)), // Monday
      ],
    );
    
    // Set profile active plan
    final profile = profileRepo.getProfile();
    await profileRepo.saveProfile(profile.copyWith(activeMealPlan: 'beginner_plan'));
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestHive();
  });

  test('Saving exercise log marks workout as partially/fully complete in daily score', () async {
    // Initial state: 0 logs, workout score should be 0
    final initialScore = container.read(dailyScoreProvider);
    expect(initialScore.workoutsScore, 0.0);

    // Save one log
    final log1 = ExerciseLog(
      date: '2023-10-02',
      exerciseName: 'Bench Press',
      sets: [SetLog(setNumber: 1, reps: 10, weight: 100)]
    );
    await logRepo.saveLog(log1);
    
    // Re-read daily score
    container.invalidate(dailyScoreProvider);
    final partialScore = container.read(dailyScoreProvider);
    expect(partialScore.workoutsScore, 0.0); // The section is not complete because Squat is missing
    
    // Save second log
    final log2 = ExerciseLog(
      date: '2023-10-02',
      exerciseName: 'Squat',
      sets: [SetLog(setNumber: 1, reps: 10, weight: 100)]
    );
    await logRepo.saveLog(log2);
    
    // Re-read daily score
    container.invalidate(dailyScoreProvider);
    final fullScore = container.read(dailyScoreProvider);
    
    print('DateStr in test: 2023-10-02');
    print('Log repo has Bench Press: ${logRepo.hasLog('2023-10-02', 'Bench Press')}');
    print('Log repo has Squat: ${logRepo.hasLog('2023-10-02', 'Squat')}');
    print('Plan dayId: ${container.read(workoutPlanProvider)?.days.first.dayId}');
    print('Plan exercises count: ${container.read(workoutPlanProvider)?.days.first.sections.first.exercises.length}');
    
    expect(fullScore.workoutsScore, 30.0); // Max score for workouts is 30
  });

  test('Rest day receives full workout score without logs', () async {
    // Sunday 2023-10-01 — recreate container (Riverpod parent + override is unsafe)
    final sundayContainer = ProviderContainer(
      overrides: [
        exerciseLogRepoProvider.overrideWithValue(logRepo),
        workoutRepoProvider.overrideWithValue(workoutRepo),
        habitRepoProvider.overrideWithValue(container.read(habitRepoProvider)),
        mealRepoProvider.overrideWithValue(container.read(mealRepoProvider)),
        dailyLogRepoProvider.overrideWithValue(container.read(dailyLogRepoProvider)),
        profileRepoProvider.overrideWithValue(container.read(profileRepoProvider)),
        selectedDateProvider.overrideWith((ref) => DateTime(2023, 10, 1)),
      ],
    );

    final score = sundayContainer.read(dailyScoreProvider);
    expect(score.workoutsScore, 30.0);
    sundayContainer.dispose();
  });

  test('Meal score uses slot.type not slot.name for completion', () async {
    final mealRepo = container.read(mealRepoProvider);
    
    // Create a meal plan with a custom display name but standard type
    final mockMealPlan = MealPlan(
      planName: 'Test Meal Plan',
      totalCalories: 1200,
      meals: [
        Meal(type: 'breakfast', name: 'Morning Fuel', calories: 500, items: []),
        Meal(type: 'lunch', name: 'Midday Power', calories: 700, items: []),
      ]
    );
    await mealRepo.savePlanJson('test_meal_plan', jsonEncode(mockMealPlan.toJson()));
    
    // Set profile active meal plan
    final profileRepo = container.read(profileRepoProvider);
    final profile = profileRepo.getProfile();
    await profileRepo.saveProfile(profile.copyWith(activeMealPlan: 'test_meal_plan'));
    
    container.invalidate(mealPlanProvider);
    container.invalidate(dailyScoreProvider);

    final initialScore = container.read(dailyScoreProvider);
    expect(initialScore.mealsScore, 0.0);

    // Add a meal log using the slot TYPE (breakfast), not the display NAME (Morning Fuel)
    final mealLog = container.read(dailyMealLogProvider.notifier);
    await mealLog.saveMealSlot('breakfast', MealSlotLog(
      items: [],
      totalCalories: 500,
      totalProtein: 30,
      totalCarbs: 50,
      totalFat: 20,
    ));

    container.invalidate(dailyScoreProvider);
    final partialScore = container.read(dailyScoreProvider);
    // 1 out of 2 meals = 10 points (max 20)
    expect(partialScore.mealsScore, 10.0);
  });

  test('DailyScore remainingLabels and isPrimaryComplete helpers', () {
    final incomplete = DailyScore(
      totalScore: 40,
      isFutureDate: false,
      habitsScore: 20,
      habitsMax: 40,
      workoutsScore: 30,
      workoutsMax: 30,
      mealsScore: 10,
      mealsMax: 20,
      stepsScore: 0,
      stepsMax: 0,
      waterScore: 0,
      waterMax: 0,
    );
    expect(incomplete.isPrimaryComplete, isFalse);
    expect(incomplete.remainingLabels, ['habits', 'meals']);

    final complete = DailyScore(
      totalScore: 100,
      isFutureDate: false,
      habitsScore: 40,
      habitsMax: 40,
      workoutsScore: 30,
      workoutsMax: 30,
      mealsScore: 20,
      mealsMax: 20,
      stepsScore: 10,
      stepsMax: 10,
      waterScore: 0,
      waterMax: 0,
    );
    expect(complete.isPrimaryComplete, isTrue);
    expect(complete.remainingLabels, isEmpty);

    final future = DailyScore(
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
    expect(future.isPrimaryComplete, isFalse);
    expect(future.remainingLabels, isEmpty);
  });
}

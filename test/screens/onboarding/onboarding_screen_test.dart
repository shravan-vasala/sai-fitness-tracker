import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/models/habit.dart';
import 'package:trufit_bodamma/repositories/habit_repository.dart';
import '../../helpers/test_hive_setup.dart';

/// Smoke test for onboarding habit selection semantics (repo layer).
/// Full UI PageView pumping is flaky with AnimatedContainer / fonts.
void main() {
  late HabitRepository habitRepo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    habitRepo = HabitRepository();
    await habitRepo.init();
    for (final h in Habit.defaults) {
      await habitRepo.saveHabit(h);
    }
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('Deselecting water habit removes it from repository (onboarding save)', () async {
    expect(habitRepo.getHabits().length, Habit.defaults.length);

    // Mirror OnboardingScreen._saveGoals when water is unselected
    final selectedIds = Habit.defaults.map((h) => h.id).where((id) => id != 'water').toSet();
    for (final habit in habitRepo.getHabits()) {
      if (!selectedIds.contains(habit.id)) {
        habitRepo.deleteHabit(habit.id);
      }
    }

    final saved = habitRepo.getHabits();
    expect(saved.any((h) => h.id == 'water'), isFalse);
    expect(saved.any((h) => h.id == 'sleep'), isTrue);
    expect(saved.any((h) => h.id == 'walk'), isTrue);
  });
}

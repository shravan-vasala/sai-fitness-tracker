import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/repositories/habit_repository.dart';
import '../helpers/test_hive_setup.dart';

void main() {
  late HabitRepository repository;

  setUp(() async {
    await setUpTestHive();
    repository = HabitRepository();
    await repository.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('should seed default habits on init', () {
    final habits = repository.getHabits();
    expect(habits, isNotEmpty);
    expect(habits.any((h) => h.id == 'water'), isTrue);
  });

  test('toggleCheckboxCompletion toggles boolean habit state', () async {
    const date = '2023-10-01';
    const habitId = 'water';
    
    // Initially false/null
    var completion = repository.getCompletions(date);
    expect(completion.completions[habitId], isNull);

    // Toggle once -> true
    await repository.toggleCheckboxCompletion(date, habitId);
    completion = repository.getCompletions(date);
    expect(completion.completions[habitId], isTrue);

    // Toggle again -> false
    await repository.toggleCheckboxCompletion(date, habitId);
    completion = repository.getCompletions(date);
    expect(completion.completions[habitId], isFalse);
  });

  test('updateProgress correctly updates numeric habits', () async {
    const date = '2023-10-01';
    const habitId = 'steps';
    
    await repository.updateProgress(date, habitId, 5000);
    var completion = repository.getCompletions(date);
    expect(completion.completions[habitId], 5000);
  });

  test('setOverride allows marking a numeric habit as completed (rest day)', () async {
    const date = '2023-10-01';
    const habitId = 'steps';
    
    await repository.setOverride(date, habitId, 'rest');
    var completion = repository.getCompletions(date);
    expect(completion.overrides[habitId], 'rest');
  });
}

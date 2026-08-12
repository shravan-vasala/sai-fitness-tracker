import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/repositories/daily_log_repository.dart';
import '../helpers/test_hive_setup.dart';

void main() {
  late DailyLogRepository repository;

  setUp(() async {
    await setUpTestHive();
    repository = DailyLogRepository();
    await repository.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('getOrCreate should create a new log if it does not exist', () {
    final log = repository.getOrCreate('2023-10-01');
    expect(log.date, '2023-10-01');
    expect(log.weight, isNull);
    expect(log.steps, isNull);
  });

  test('updateWeight should save and update weight correctly', () async {
    await repository.updateWeight('2023-10-01', 75.5);
    final log = repository.getLog('2023-10-01');
    expect(log, isNotNull);
    expect(log!.weight, 75.5);
  });

  test('updateSteps should save and update steps correctly', () async {
    await repository.updateSteps('2023-10-01', 10000, source: 'manual');
    final log = repository.getLog('2023-10-01');
    expect(log, isNotNull);
    expect(log!.steps, 10000);
    expect(log.stepsSource, 'manual');
  });

  test('markWorkoutCompleted should correctly update workout status', () async {
    await repository.markWorkoutCompleted('2023-10-01', 'day_1');
    final log = repository.getLog('2023-10-01');
    expect(log, isNotNull);
    expect(log!.workoutCompleted, isTrue);
    expect(log.workoutDayId, 'day_1');
  });
}

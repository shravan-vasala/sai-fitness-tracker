import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/repositories/exercise_log_repository.dart';
import 'package:trufit_bodamma/models/exercise_log.dart';
import '../helpers/test_hive_setup.dart';

void main() {
  late ExerciseLogRepository repository;

  setUp(() async {
    await setUpTestHive();
    repository = ExerciseLogRepository();
    await repository.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('saveLog and hasLog verify a log exists', () async {
    final log = ExerciseLog(
      date: '2023-10-01',
      exerciseName: 'Bench Press',
      sets: [],
    );

    expect(repository.hasLog('2023-10-01', 'Bench Press'), isFalse);

    await repository.saveLog(log);

    expect(repository.hasLog('2023-10-01', 'Bench Press'), isTrue);
    final fetchedLog = repository.getLog('2023-10-01', 'Bench Press');
    expect(fetchedLog, isNotNull);
    expect(fetchedLog!.exerciseName, 'Bench Press');
  });

  test('getLogsForExercise returns all logs sorted by date', () async {
    final log1 = ExerciseLog(
      date: '2023-10-05',
      exerciseName: 'Squat',
      sets: [],
    );
    final log2 = ExerciseLog(
      date: '2023-10-01',
      exerciseName: 'Squat',
      sets: [],
    );

    await repository.saveLog(log1);
    await repository.saveLog(log2);

    final logs = repository.getLogsForExercise('Squat');
    expect(logs.length, 2);
    // Should be sorted by date
    expect(logs.first.date, '2023-10-01');
    expect(logs.last.date, '2023-10-05');
  });
}

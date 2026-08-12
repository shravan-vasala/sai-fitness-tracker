import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trufit_bodamma/services/csv_export_service.dart';
import 'package:trufit_bodamma/models/daily_log.dart';
import 'package:trufit_bodamma/models/habit.dart';

import '../helpers/test_hive_setup.dart';

void main() {
  late CsvExportService exportService;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    tempDir = Directory.systemTemp.createTempSync('csv_export_test_');

    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return tempDir.path;
    });

    exportService = CsvExportService();
  });

  tearDown(() async {
    await tearDownTestHive();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('exportData reads daily_logs and habit_config boxes', () async {
    final dailyLogs = await Hive.openBox<DailyLog>('daily_logs_v2');
    await dailyLogs.put(
      '2023-10-01',
      DailyLog(
        date: '2023-10-01',
        weight: 70.5,
        steps: 8000,
        workoutCompleted: true,
        workoutDayId: 'day_1',
      ),
    );

    final habitConfig = await Hive.openBox<Habit>('habit_config_v2');
    await habitConfig.put(
      'water',
      Habit(
        id: 'water',
        name: 'Drink water',
        icon: '💧',
        type: HabitType.checkbox,
        target: 3.0,
        step: 1.0,
        unit: 'L',
        order: 0,
      ),
    );

    final habitCompletions = await Hive.openBox<HabitCompletion>('habit_completions_v2');
    await habitCompletions.put(
      '2023-10-01',
      HabitCompletion(
        date: '2023-10-01',
        completions: {'water': true},
        overrides: <String, String>{},
      ),
    );

    final zipPath = await exportService.exportData(null);
    expect(zipPath, isNotNull);

    final archive = ZipDecoder().decodeBytes(await File(zipPath!).readAsBytes());

    final dailyCsv = archive.findFile('daily_logs.csv');
    expect(dailyCsv, isNotNull);
    final dailyText = utf8.decode(dailyCsv!.content as List<int>);
    expect(dailyText, contains('2023-10-01'));
    expect(dailyText, contains('70.5'));
    expect(dailyText, contains('8000'));

    final habitsCsv = archive.findFile('habits.csv');
    expect(habitsCsv, isNotNull);
    final habitsText = utf8.decode(habitsCsv!.content as List<int>);
    expect(habitsText, contains('water'));
    expect(habitsText, contains('Drink water'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/models/daily_log.dart';
import 'package:trufit_bodamma/models/workout_plan.dart';
import 'package:trufit_bodamma/utils/workout_completion.dart';

void main() {
  final trainingDay = WorkoutDay(
    dayId: 'day_1',
    label: 'Monday',
    sections: [
      WorkoutSection(
        title: 'Main',
        exercises: [
          Exercise(name: 'Bench Press', reps: ['10']),
          Exercise(name: 'Squat', reps: ['10']),
        ],
      ),
    ],
  );

  final restDay = WorkoutDay(
    dayId: 'Rest',
    label: 'Sunday',
    sections: [],
  );

  final monday = DateTime(2023, 10, 2); // Monday
  final sunday = DateTime(2023, 10, 1); // Sunday

  test('isRestDay is true for Sunday or empty sections', () {
    expect(WorkoutCompletion.isRestDay(trainingDay, sunday), isTrue);
    expect(WorkoutCompletion.isRestDay(restDay, monday), isTrue);
    expect(WorkoutCompletion.isRestDay(trainingDay, monday), isFalse);
  });

  test('training day incomplete / complete via logs', () {
    final logged = <String>{};

    bool hasLog(String date, String name) => logged.contains('$date|$name');

    expect(
      WorkoutCompletion.isTrainingDayComplete('2023-10-02', trainingDay, hasLog),
      isFalse,
    );
    expect(
      WorkoutCompletion.isDayWorkoutDone(
        date: '2023-10-02',
        day: trainingDay,
        dateTime: monday,
        hasLog: hasLog,
        dailyLog: DailyLog(date: '2023-10-02'),
      ),
      isFalse,
    );

    logged.add('2023-10-02|Bench Press');
    expect(
      WorkoutCompletion.isTrainingDayComplete('2023-10-02', trainingDay, hasLog),
      isFalse,
    );

    logged.add('2023-10-02|Squat');
    expect(
      WorkoutCompletion.isTrainingDayComplete('2023-10-02', trainingDay, hasLog),
      isTrue,
    );
    expect(
      WorkoutCompletion.isDayWorkoutDone(
        date: '2023-10-02',
        day: trainingDay,
        dateTime: monday,
        hasLog: hasLog,
        dailyLog: DailyLog(date: '2023-10-02'),
      ),
      isTrue,
    );
  });

  test('Finish-early / skip via DailyLog.workoutCompleted counts as day done', () {
    bool hasLog(String date, String name) => false;

    expect(
      WorkoutCompletion.isDayWorkoutDone(
        date: '2023-10-02',
        day: trainingDay,
        dateTime: monday,
        hasLog: hasLog,
        dailyLog: DailyLog(date: '2023-10-02', workoutCompleted: true),
      ),
      isTrue,
    );
  });

  test('rest day scores as done', () {
    bool hasLog(String date, String name) => false;

    expect(
      WorkoutCompletion.isDayWorkoutDone(
        date: '2023-10-01',
        day: restDay,
        dateTime: sunday,
        hasLog: hasLog,
        dailyLog: DailyLog(date: '2023-10-01'),
      ),
      isTrue,
    );
  });

  test('resolveWorkoutDay maps weekday to plan day', () {
    final plan = WorkoutPlan(
      planName: 'Test',
      days: [
        WorkoutDay(dayId: 'day_1', sections: trainingDay.sections),
        WorkoutDay(dayId: 'day_2', sections: trainingDay.sections),
        WorkoutDay(dayId: 'day_3', sections: trainingDay.sections),
        WorkoutDay(dayId: 'day_4', sections: trainingDay.sections),
        WorkoutDay(dayId: 'day_5', sections: trainingDay.sections),
        WorkoutDay(dayId: 'day_6', sections: trainingDay.sections),
        restDay,
      ],
    );

    expect(WorkoutCompletion.resolveWorkoutDay(plan, monday).dayId, 'day_1');
    expect(
      WorkoutCompletion.isRestDay(
        WorkoutCompletion.resolveWorkoutDay(plan, sunday),
        sunday,
      ),
      isTrue,
    );
  });
}

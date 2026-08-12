import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'body_stats.dart';
import 'coach_note.dart';
import 'daily_log.dart';
import 'daily_meal_log.dart';
import 'exercise_log.dart';
import 'exercise_pr.dart';
import 'habit.dart';
import 'meal_plan.dart';
import 'progress_photo.dart';
import 'reminder_config.dart';
import 'scanned_meal_log.dart';
import 'user_profile.dart';
import 'workout_plan.dart';

class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  @override
  final int typeId = 0;

  @override
  TimeOfDay read(BinaryReader reader) {
    final str = reader.readString();
    final parts = str.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeString('${obj.hour}:${obj.minute}');
  }
}



class BodyStatsAdapter extends TypeAdapter<BodyStats> {
  @override
  final int typeId = 1;

  @override
  BodyStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyStats(
      date: fields[0] as String,
      waist: fields[1] as double?,
      hips: fields[2] as double?,
      chest: fields[3] as double?,
      leftArm: fields[4] as double?,
      rightArm: fields[5] as double?,
      leftThigh: fields[6] as double?,
      rightThigh: fields[7] as double?,
      neck: fields[8] as double?,
      unit: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BodyStats obj) {
    writer.writeByte(10);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.waist);
    writer.writeByte(2);
    writer.write(obj.hips);
    writer.writeByte(3);
    writer.write(obj.chest);
    writer.writeByte(4);
    writer.write(obj.leftArm);
    writer.writeByte(5);
    writer.write(obj.rightArm);
    writer.writeByte(6);
    writer.write(obj.leftThigh);
    writer.writeByte(7);
    writer.write(obj.rightThigh);
    writer.writeByte(8);
    writer.write(obj.neck);
    writer.writeByte(9);
    writer.write(obj.unit);
  }
}

class CoachNoteAdapter extends TypeAdapter<CoachNote> {
  @override
  final int typeId = 2;

  @override
  CoachNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachNote(
      date: fields[0] as String,
      note: fields[1] as String,
      isAi: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CoachNote obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.note);
    writer.writeByte(2);
    writer.write(obj.isAi);
  }
}

class DailyLogAdapter extends TypeAdapter<DailyLog> {
  @override
  final int typeId = 3;

  @override
  DailyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyLog(
      date: fields[0] as String,
      weight: fields[1] as double?,
      steps: fields[2] as int?,
      stepsSource: fields[3] as String?,
      sleepHours: fields[4] as double?,
      sleepSource: fields[5] as String?,
      bodyFat: fields[6] as double?,
      workoutCompleted: fields[7] as bool,
      workoutDayId: fields[8] as String?,
      waterMl: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyLog obj) {
    writer.writeByte(10);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.weight);
    writer.writeByte(2);
    writer.write(obj.steps);
    writer.writeByte(3);
    writer.write(obj.stepsSource);
    writer.writeByte(4);
    writer.write(obj.sleepHours);
    writer.writeByte(5);
    writer.write(obj.sleepSource);
    writer.writeByte(6);
    writer.write(obj.bodyFat);
    writer.writeByte(7);
    writer.write(obj.workoutCompleted);
    writer.writeByte(8);
    writer.write(obj.workoutDayId);
    writer.writeByte(9);
    writer.write(obj.waterMl);
  }
}

class DailyMealLogAdapter extends TypeAdapter<DailyMealLog> {
  @override
  final int typeId = 4;

  @override
  DailyMealLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyMealLog(
      date: fields[0] as String,
      customSlots: (fields[1] as Map?)?.cast<String, MealSlotLog>() ?? {},
    );
  }

  @override
  void write(BinaryWriter writer, DailyMealLog obj) {
    writer.writeByte(2);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.customSlots);
  }
}

class MealSlotLogAdapter extends TypeAdapter<MealSlotLog> {
  @override
  final int typeId = 5;

  @override
  MealSlotLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealSlotLog(
      name: fields[0] as String?,
      emoji: fields[1] as String?,
      photoPath: fields[2] as String?,
      items: fields[3] ?.cast<MealItemLog>() ?? [],
      totalCalories: fields[4] as int,
      totalProtein: fields[5] as double,
      totalCarbs: fields[6] as double,
      totalFat: fields[7] as double,
      confidence: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealSlotLog obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.emoji);
    writer.writeByte(2);
    writer.write(obj.photoPath);
    writer.writeByte(3);
    writer.write(obj.items);
    writer.writeByte(4);
    writer.write(obj.totalCalories);
    writer.writeByte(5);
    writer.write(obj.totalProtein);
    writer.writeByte(6);
    writer.write(obj.totalCarbs);
    writer.writeByte(7);
    writer.write(obj.totalFat);
    writer.writeByte(8);
    writer.write(obj.confidence);
  }
}

class MealItemLogAdapter extends TypeAdapter<MealItemLog> {
  @override
  final int typeId = 6;

  @override
  MealItemLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealItemLog(
      name: fields[0] as String,
      portion: fields[1] as String,
      calories: fields[2] as int,
      proteinG: fields[3] as double,
      carbsG: fields[4] as double,
      fatG: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MealItemLog obj) {
    writer.writeByte(6);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.portion);
    writer.writeByte(2);
    writer.write(obj.calories);
    writer.writeByte(3);
    writer.write(obj.proteinG);
    writer.writeByte(4);
    writer.write(obj.carbsG);
    writer.writeByte(5);
    writer.write(obj.fatG);
  }
}

class ExerciseLogAdapter extends TypeAdapter<ExerciseLog> {
  @override
  final int typeId = 7;

  @override
  ExerciseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseLog(
      date: fields[0] as String,
      exerciseName: fields[1] as String,
      sets: fields[2] ?.cast<SetLog>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseLog obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.exerciseName);
    writer.writeByte(2);
    writer.write(obj.sets);
  }
}

class SetLogAdapter extends TypeAdapter<SetLog> {
  @override
  final int typeId = 8;

  @override
  SetLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetLog(
      setNumber: fields[0] as int,
      reps: fields[1] as int,
      weight: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SetLog obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.setNumber);
    writer.writeByte(1);
    writer.write(obj.reps);
    writer.writeByte(2);
    writer.write(obj.weight);
  }
}

class ExercisePrAdapter extends TypeAdapter<ExercisePr> {
  @override
  final int typeId = 9;

  @override
  ExercisePr read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExercisePr(
      exerciseName: fields[0] as String,
      maxWeight: fields[1] as double,
      maxWeightReps: fields[2] as int,
      maxReps: fields[3] as int,
      maxRepsWeight: fields[4] as double,
      estimated1RM: fields[5] as double,
      maxVolume: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ExercisePr obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.exerciseName);
    writer.writeByte(1);
    writer.write(obj.maxWeight);
    writer.writeByte(2);
    writer.write(obj.maxWeightReps);
    writer.writeByte(3);
    writer.write(obj.maxReps);
    writer.writeByte(4);
    writer.write(obj.maxRepsWeight);
    writer.writeByte(5);
    writer.write(obj.estimated1RM);
    writer.writeByte(6);
    writer.write(obj.maxVolume);
  }
}

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 10;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String,
      type: HabitType.values.firstWhere((e) => e.name == (fields[3] as String?), orElse: () => HabitType.checkbox),
      unit: fields[4] as String,
      target: fields[5] as double,
      step: fields[6] as double,
      createdAt: fields[7] as DateTime,
      order: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.icon);
    writer.writeByte(3);
    writer.write(obj.type.name);
    writer.writeByte(4);
    writer.write(obj.unit);
    writer.writeByte(5);
    writer.write(obj.target);
    writer.writeByte(6);
    writer.write(obj.step);
    writer.writeByte(7);
    writer.write(obj.createdAt);
    writer.writeByte(8);
    writer.write(obj.order);
  }
}

class HabitCompletionAdapter extends TypeAdapter<HabitCompletion> {
  @override
  final int typeId = 11;

  @override
  HabitCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitCompletion(
      date: fields[0] as String,
      completions: (fields[1] as Map?)?.cast<String, dynamic>() ?? {},
      overrides: (fields[2] as Map?)?.cast<String, String>() ?? {},
      streaks: (fields[3] as Map?)?.cast<String, int>() ?? {},
    );
  }

  @override
  void write(BinaryWriter writer, HabitCompletion obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.completions);
    writer.writeByte(2);
    writer.write(obj.overrides);
    writer.writeByte(3);
    writer.write(obj.streaks);
  }
}

class MealPlanAdapter extends TypeAdapter<MealPlan> {
  @override
  final int typeId = 12;

  @override
  MealPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlan(
      planName: fields[0] as String,
      meals: fields[1] ?.cast<Meal>() ?? [],
      totalCalories: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlan obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.planName);
    writer.writeByte(1);
    writer.write(obj.meals);
    writer.writeByte(2);
    writer.write(obj.totalCalories);
  }
}

class MealAdapter extends TypeAdapter<Meal> {
  @override
  final int typeId = 13;

  @override
  Meal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Meal(
      name: fields[0] as String,
      type: fields[1] as String,
      items: fields[2] ?.cast<MealItem>() ?? [],
      calories: fields[3] as int,
      isCompleted: fields[4] as bool,
      suggestions: fields[5] ?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, Meal obj) {
    writer.writeByte(6);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.type);
    writer.writeByte(2);
    writer.write(obj.items);
    writer.writeByte(3);
    writer.write(obj.calories);
    writer.writeByte(4);
    writer.write(obj.isCompleted);
    writer.writeByte(5);
    writer.write(obj.suggestions);
  }
}

class MealItemAdapter extends TypeAdapter<MealItem> {
  @override
  final int typeId = 14;

  @override
  MealItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealItem(
      name: fields[0] as String,
      quantity: fields[1] as String,
      calories: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MealItem obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.quantity);
    writer.writeByte(2);
    writer.write(obj.calories);
  }
}

class ProgressPhotoAdapter extends TypeAdapter<ProgressPhoto> {
  @override
  final int typeId = 15;

  @override
  ProgressPhoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressPhoto(
      path: fields[0] as String,
      date: fields[1] as String,
      pose: fields[2] as String,
      weight: fields[3] as double?,
      note: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressPhoto obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.path);
    writer.writeByte(1);
    writer.write(obj.date);
    writer.writeByte(2);
    writer.write(obj.pose);
    writer.writeByte(3);
    writer.write(obj.weight);
    writer.writeByte(4);
    writer.write(obj.note);
  }
}

class ReminderConfigAdapter extends TypeAdapter<ReminderConfig> {
  @override
  final int typeId = 16;

  @override
  ReminderConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderConfig(
      habitsEnabled: fields[0] as bool,
      habitTime: fields[1] as TimeOfDay,
      workoutsEnabled: fields[2] as bool,
      workoutTime: fields[3] as TimeOfDay,
      mealsEnabled: fields[4] as bool,
      lunchTime: fields[5] as TimeOfDay,
      dinnerTime: fields[6] as TimeOfDay,
      backupEnabled: fields[7] as bool,
      backupDayOfWeek: fields[8] as int,
      backupTime: fields[9] as TimeOfDay,
      photosEnabled: fields[10] as bool,
      photoTime: fields[11] as TimeOfDay,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderConfig obj) {
    writer.writeByte(12);
    writer.writeByte(0);
    writer.write(obj.habitsEnabled);
    writer.writeByte(1);
    writer.write(obj.habitTime);
    writer.writeByte(2);
    writer.write(obj.workoutsEnabled);
    writer.writeByte(3);
    writer.write(obj.workoutTime);
    writer.writeByte(4);
    writer.write(obj.mealsEnabled);
    writer.writeByte(5);
    writer.write(obj.lunchTime);
    writer.writeByte(6);
    writer.write(obj.dinnerTime);
    writer.writeByte(7);
    writer.write(obj.backupEnabled);
    writer.writeByte(8);
    writer.write(obj.backupDayOfWeek);
    writer.writeByte(9);
    writer.write(obj.backupTime);
    writer.writeByte(10);
    writer.write(obj.photosEnabled);
    writer.writeByte(11);
    writer.write(obj.photoTime);
  }
}

class ScannedMealLogAdapter extends TypeAdapter<ScannedMealLog> {
  @override
  final int typeId = 17;

  @override
  ScannedMealLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScannedMealLog(
      id: fields[0] as String,
      date: fields[1] as String,
      photoPath: fields[2] as String,
      mealType: fields[3] as String,
      foodName: fields[4] as String,
      estimatedCalories: fields[5] as int,
      proteinGrams: fields[6] as double,
      carbsGrams: fields[7] as double,
      fatGrams: fields[8] as double,
      portionMultiplier: fields[9] as double,
      timestamp: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScannedMealLog obj) {
    writer.writeByte(11);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.date);
    writer.writeByte(2);
    writer.write(obj.photoPath);
    writer.writeByte(3);
    writer.write(obj.mealType);
    writer.writeByte(4);
    writer.write(obj.foodName);
    writer.writeByte(5);
    writer.write(obj.estimatedCalories);
    writer.writeByte(6);
    writer.write(obj.proteinGrams);
    writer.writeByte(7);
    writer.write(obj.carbsGrams);
    writer.writeByte(8);
    writer.write(obj.fatGrams);
    writer.writeByte(9);
    writer.write(obj.portionMultiplier);
    writer.writeByte(10);
    writer.write(obj.timestamp);
  }
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 18;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      coachName: fields[1] as String,
      photoPath: fields[2] as String?,
      height: fields[3] as double,
      targetWeight: fields[4] as double?,
      useKg: fields[5] as bool,
      targetCalories: fields[6] as int,
      activeWorkoutPlan: fields[7] as String?,
      activeMealPlan: fields[8] as String?,
      customHabits: (fields[9] as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? [],
      customMealSlots: (fields[10] as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? [],
      geminiApiKey: fields[11] as String?,
      restTimerSound: fields[12] as bool,
      restTimerVibration: fields[13] as bool,
      targetProteinG: fields[14] as int,
      targetCarbsG: fields[15] as int,
      targetFatG: fields[16] as int,
      planStartDate: fields[17] as DateTime?,
      currentPhaseWeek: fields[18] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer.writeByte(19);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.coachName);
    writer.writeByte(2);
    writer.write(obj.photoPath);
    writer.writeByte(3);
    writer.write(obj.height);
    writer.writeByte(4);
    writer.write(obj.targetWeight);
    writer.writeByte(5);
    writer.write(obj.useKg);
    writer.writeByte(6);
    writer.write(obj.targetCalories);
    writer.writeByte(7);
    writer.write(obj.activeWorkoutPlan);
    writer.writeByte(8);
    writer.write(obj.activeMealPlan);
    writer.writeByte(9);
    writer.write(obj.customHabits);
    writer.writeByte(10);
    writer.write(obj.customMealSlots);
    writer.writeByte(11);
    writer.write(obj.geminiApiKey);
    writer.writeByte(12);
    writer.write(obj.restTimerSound);
    writer.writeByte(13);
    writer.write(obj.restTimerVibration);
    writer.writeByte(14);
    writer.write(obj.targetProteinG);
    writer.writeByte(15);
    writer.write(obj.targetCarbsG);
    writer.writeByte(16);
    writer.write(obj.targetFatG);
    writer.writeByte(17);
    writer.write(obj.planStartDate);
    writer.writeByte(18);
    writer.write(obj.currentPhaseWeek);
  }
}

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final int typeId = 19;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlan(
      planName: fields[0] as String,
      days: fields[1] ?.cast<WorkoutDay>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer.writeByte(2);
    writer.writeByte(0);
    writer.write(obj.planName);
    writer.writeByte(1);
    writer.write(obj.days);
  }
}

class WorkoutDayAdapter extends TypeAdapter<WorkoutDay> {
  @override
  final int typeId = 20;

  @override
  WorkoutDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutDay(
      dayId: fields[0] as String,
      label: fields[1] as String?,
      sections: fields[2] ?.cast<WorkoutSection>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutDay obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.dayId);
    writer.writeByte(1);
    writer.write(obj.label);
    writer.writeByte(2);
    writer.write(obj.sections);
  }
}

class WorkoutSectionAdapter extends TypeAdapter<WorkoutSection> {
  @override
  final int typeId = 21;

  @override
  WorkoutSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSection(
      title: fields[0] as String,
      exercises: fields[1] ?.cast<Exercise>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSection obj) {
    writer.writeByte(2);
    writer.writeByte(0);
    writer.write(obj.title);
    writer.writeByte(1);
    writer.write(obj.exercises);
  }
}

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 22;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      name: fields[0] as String,
      displayName: fields[1] as String?,
      youtubeUrl: fields[2] as String?,
      reps: fields[3] ?.cast<String>() ?? [],
      note: fields[4] as String,
      sideInfo: fields[5] as String,
      restSecondsAfterSet: fields[6] as int,
      weightKg: fields[7] as double?,
      durationSeconds: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.displayName);
    writer.writeByte(2);
    writer.write(obj.youtubeUrl);
    writer.writeByte(3);
    writer.write(obj.reps);
    writer.writeByte(4);
    writer.write(obj.note);
    writer.writeByte(5);
    writer.write(obj.sideInfo);
    writer.writeByte(6);
    writer.write(obj.restSecondsAfterSet);
    writer.writeByte(7);
    writer.write(obj.weightKg);
    writer.writeByte(8);
    writer.write(obj.durationSeconds);
  }
}
void registerHiveAdapters() {
  Hive.registerAdapter(TimeOfDayAdapter());
  Hive.registerAdapter(BodyStatsAdapter());
  Hive.registerAdapter(CoachNoteAdapter());
  Hive.registerAdapter(DailyLogAdapter());
  Hive.registerAdapter(DailyMealLogAdapter());
  Hive.registerAdapter(MealSlotLogAdapter());
  Hive.registerAdapter(MealItemLogAdapter());
  Hive.registerAdapter(ExerciseLogAdapter());
  Hive.registerAdapter(SetLogAdapter());
  Hive.registerAdapter(ExercisePrAdapter());
  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(HabitCompletionAdapter());
  Hive.registerAdapter(MealPlanAdapter());
  Hive.registerAdapter(MealAdapter());
  Hive.registerAdapter(MealItemAdapter());
  Hive.registerAdapter(ProgressPhotoAdapter());
  Hive.registerAdapter(ReminderConfigAdapter());
  Hive.registerAdapter(ScannedMealLogAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(WorkoutPlanAdapter());
  Hive.registerAdapter(WorkoutDayAdapter());
  Hive.registerAdapter(WorkoutSectionAdapter());
  Hive.registerAdapter(ExerciseAdapter());
}

import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/body_stats.dart';
import '../models/coach_note.dart';
import '../models/daily_log.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../models/habit.dart';
import '../models/daily_meal_log.dart';
import '../models/meal_plan.dart';
import '../models/scanned_meal_log.dart';
import '../models/user_profile.dart';
import '../models/workout_plan.dart';
import '../models/progress_photo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchemaMigrationService {
  static const int currentSchemaVersion = 3;
  static const String _versionKey = 'schema_version';

  /// Run migrations for the active Hive data on application startup.
  static Future<void> runStartupMigrations(SharedPreferences prefs) async {
    final int storedVersion = prefs.getInt(_versionKey) ?? 1;

    if (storedVersion >= currentSchemaVersion) {
      return; // Already up to date
    }

    int workingVersion = storedVersion;

    if (workingVersion < 2) {
      await _migrateV1ToV2Startup();
      workingVersion = 2;
    }

    if (workingVersion < 3) {
      await _migrateV2ToV3Startup();
      workingVersion = 3;
    }

    // After all migrations succeed, update the stored version
    await prefs.setInt(_versionKey, currentSchemaVersion);
  }

  /// Run migrations for in-memory backup data before writing to Hive during a restore.
  static Map<String, dynamic> runMigrationsForRestore(
    Map<String, dynamic> boxes,
    int manifestVersion,
  ) {
    if (manifestVersion >= currentSchemaVersion) {
      return boxes;
    }

    int workingVersion = manifestVersion;

    if (workingVersion < 2) {
      _migrateV1ToV2Restore(boxes);
      workingVersion = 2;
    }

    return boxes;
  }

  // ─── Migrations V1 -> V2 ───────────────────────────────────────────────────
  
  static Future<void> _migrateV1ToV2Startup() async {
    final box = await Hive.openBox<String>('user_profile');
    final jsonStr = box.get('profile');
    if (jsonStr != null) {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      _applyV2UserProfileChanges(map);
      await box.put('profile', jsonEncode(map));
    }
  }

  static void _migrateV1ToV2Restore(Map<String, dynamic> boxes) {
    if (boxes.containsKey('user_profile')) {
      final boxData = boxes['user_profile'] as Map<String, dynamic>;
      if (boxData.containsKey('profile')) {
        final map = jsonDecode(boxData['profile'].toString()) as Map<String, dynamic>;
        _applyV2UserProfileChanges(map);
        boxData['profile'] = jsonEncode(map);
      }
    }
  }

  static void _applyV2UserProfileChanges(Map<String, dynamic> map) {
    map.putIfAbsent('targetProteinG', () => 120);
    map.putIfAbsent('targetCarbsG', () => 150);
    map.putIfAbsent('targetFatG', () => 50);
    if (!map.containsKey('planStartDate')) {
      map['planStartDate'] = null;
    }
    map.putIfAbsent('currentPhaseWeek', () => 1);
    map.putIfAbsent('restTimerSound', () => true);
    map.putIfAbsent('restTimerVibration', () => true);
  }
  static Future<void> _migrateV2ToV3Startup() async {
    try {
      if (await Hive.boxExists('body_stats')) {
        final oldBox = await Hive.openBox<String>('body_stats');
        final newBox = await Hive.openBox<BodyStats>('body_stats_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, BodyStats.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in body_stats: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating body_stats: ');
    }
    try {
      if (await Hive.boxExists('coach_notes')) {
        final oldBox = await Hive.openBox<String>('coach_notes');
        final newBox = await Hive.openBox<CoachNote>('coach_notes_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, CoachNote.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in coach_notes: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating coach_notes: ');
    }
    try {
      if (await Hive.boxExists('daily_logs')) {
        final oldBox = await Hive.openBox<String>('daily_logs');
        final newBox = await Hive.openBox<DailyLog>('daily_logs_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, DailyLog.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in daily_logs: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating daily_logs: ');
    }
    try {
      if (await Hive.boxExists('exercise_logs')) {
        final oldBox = await Hive.openBox<String>('exercise_logs');
        final newBox = await Hive.openBox<ExerciseLog>('exercise_logs_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, ExerciseLog.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in exercise_logs: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating exercise_logs: ');
    }
    try {
      if (await Hive.boxExists('exercise_prs')) {
        final oldBox = await Hive.openBox<String>('exercise_prs');
        final newBox = await Hive.openBox<ExercisePr>('exercise_prs_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, ExercisePr.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in exercise_prs: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating exercise_prs: ');
    }
    try {
      if (await Hive.boxExists('habit_config')) {
        final oldBox = await Hive.openBox<String>('habit_config');
        final newBox = await Hive.openBox<Habit>('habit_config_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, Habit.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in habit_config: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating habit_config: ');
    }
    try {
      if (await Hive.boxExists('habit_completions')) {
        final oldBox = await Hive.openBox<String>('habit_completions');
        final newBox = await Hive.openBox<HabitCompletion>('habit_completions_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, HabitCompletion.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in habit_completions: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating habit_completions: ');
    }
    try {
      if (await Hive.boxExists('daily_meal_logs')) {
        final oldBox = await Hive.openBox<String>('daily_meal_logs');
        final newBox = await Hive.openBox<DailyMealLog>('daily_meal_logs_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, DailyMealLog.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in daily_meal_logs: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating daily_meal_logs: ');
    }
    try {
      if (await Hive.boxExists('meal_plans')) {
        final oldBox = await Hive.openBox<String>('meal_plans');
        final newBox = await Hive.openBox<MealPlan>('meal_plans_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, MealPlan.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in meal_plans: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating meal_plans: ');
    }
    try {
      if (await Hive.boxExists('scanned_photo_meals')) {
        final oldBox = await Hive.openBox<String>('scanned_photo_meals');
        final newBox = await Hive.openBox<ScannedMealLog>('scanned_photo_meals_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, ScannedMealLog.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in scanned_photo_meals: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating scanned_photo_meals: ');
    }
    try {
      if (await Hive.boxExists('user_profile')) {
        final oldBox = await Hive.openBox<String>('user_profile');
        final newBox = await Hive.openBox<UserProfile>('user_profile_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, UserProfile.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in user_profile: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating user_profile: ');
    }
    try {
      if (await Hive.boxExists('workout_plans')) {
        final oldBox = await Hive.openBox<String>('workout_plans');
        final newBox = await Hive.openBox<WorkoutPlan>('workout_plans_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            try {
              final jsonStr = oldBox.get(key);
              if (jsonStr != null) {
                final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                newBox.put(key, WorkoutPlan.fromJson(map));
              }
            } catch (e) {
              print('Error migrating  in workout_plans: ');
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {
      print('Error migrating workout_plans: ');
    }

    // Special handling for workout_sessions (keeps String)
    try {
      if (await Hive.boxExists('workout_sessions')) {
        final oldBox = await Hive.openBox<String>('workout_sessions');
        final newBox = await Hive.openBox<String>('workout_sessions_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            newBox.put(key, oldBox.get(key)!);
          }
        }
        await oldBox.close();
      }
    } catch (e) {}

    // Special handling for media_metadata -> media_meta_v2
    try {
      if (await Hive.boxExists('media_metadata')) {
        final oldBox = await Hive.openBox<String>('media_metadata');
        final newBox = await Hive.openBox<ProgressPhoto>('media_meta_v2');
        if (newBox.isEmpty) {
          for (final key in oldBox.keys) {
            final keyStr = key.toString();
            if (keyStr.startsWith('meta_')) {
              try {
                final jsonStr = oldBox.get(keyStr);
                if (jsonStr != null) {
                  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                  final photo = ProgressPhoto.fromJson(map);
                  newBox.put(photo.path, photo);
                }
              } catch (_) {}
            }
          }
        }
        await oldBox.close();
      }
    } catch (e) {}
  }

}

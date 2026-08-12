import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/scanned_meal_log.dart';

class PhotoMealRepository {
  static const String _boxName = 'scanned_photo_meals_v2';

  late Box<ScannedMealLog> _box;
  late String _baseDir;

  Future<void> init() async {
    _box = await Hive.openBox<ScannedMealLog>(_boxName);
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = '${appDir.path}/trufit_meal_photos';
      await Directory(_baseDir).create(recursive: true);
    } else {
      _baseDir = 'trufit_meal_photos';
    }
  }

  Future<ScannedMealLog> saveScannedMeal({
    required String date,
    required String sourcePhotoPath,
    required String mealType,
    required String foodName,
    required int estimatedCalories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    required double portionMultiplier,
  }) async {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final ext = sourcePhotoPath.contains('.') ? sourcePhotoPath.split('.').last : 'jpg';
    final destPath = kIsWeb
        ? sourcePhotoPath
        : '$_baseDir/${date}_$timestampMs.$ext';

    if (!kIsWeb) {
      await File(sourcePhotoPath).copy(destPath);
    }

    final log = ScannedMealLog(
      id: 'photo_meal_$timestampMs',
      date: date,
      photoPath: destPath,
      mealType: mealType,
      foodName: foodName,
      estimatedCalories: estimatedCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      portionMultiplier: portionMultiplier,
      timestamp: DateTime.now().toIso8601String(),
    );

    await _box.put(log.id, log);
    return log;
  }

  List<ScannedMealLog> getScannedMealsForDate(String date) {
    final logs = <ScannedMealLog>[];
    for (final log in _box.values) {
      if (log.date == date) {
        logs.add(log);
      }
    }
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  int getTotalScannedCaloriesForDate(String date) {
    final meals = getScannedMealsForDate(date);
    return meals.fold(0, (sum, m) => sum + m.totalCalories);
  }

  Future<void> deleteScannedMeal(String id) async {
    final log = _box.get(id);
    if (log != null) {
      if (!kIsWeb) {
        final file = File(log.photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await _box.delete(id);
    }
  }
}

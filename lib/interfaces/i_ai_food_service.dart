import 'dart:typed_data';

abstract class IAiFoodService {
  Future<Map<String, dynamic>?> analyzeFoodImage(
    Uint8List imageBytes,
    String mimeType, [
    String? userContext,
  ]);

  Future<Map<String, dynamic>?> analyzeFoodText(String description);

  Future<Map<String, dynamic>?> suggestMeal({
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    String? mealName,
    int? mealsLeft,
    List<String>? previousMeals,
  });

  Future<void> verifyApiKey(String key);
}

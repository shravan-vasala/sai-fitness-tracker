import '../models/daily_meal_log.dart';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';

/// Shared helpers for logging a meal slot from the seed / active meal plan.
class MealPlanComplete {
  MealPlanComplete._();

  static bool isSlotLogged(MealSlotLog? log) {
    if (log == null) return false;
    return log.items.isNotEmpty ||
        log.photoPath != null ||
        log.totalCalories > 0;
  }

  static bool isPlannedComplete(MealSlotLog? log) {
    return isSlotLogged(log) && log!.confidence == 'planned';
  }

  static Meal? plannedForSlot(MealPlan? plan, String slotId) {
    if (plan == null) return null;
    for (final m in plan.meals) {
      if (m.type == slotId) return m;
    }
    return null;
  }

  static MealSlotLog buildSlotLog({
    required Meal planned,
    required String slotName,
    required String slotEmoji,
    required UserProfile profile,
  }) {
    final mealCals = planned.calories.toDouble();
    final dayCals = profile.targetCalories > 0
        ? profile.targetCalories.toDouble()
        : mealCals;
    final share = dayCals > 0 ? mealCals / dayCals : 0.0;
    final protein = profile.targetProteinG * share;
    final carbs = profile.targetCarbsG * share;
    final fat = profile.targetFatG * share;

    final items = planned.items.map((item) {
      final itemShare =
          planned.calories > 0 ? item.calories / planned.calories : 0.0;
      return MealItemLog(
        name: item.name,
        portion: item.quantity,
        calories: item.calories,
        proteinG: protein * itemShare,
        carbsG: carbs * itemShare,
        fatG: fat * itemShare,
      );
    }).toList();

    return MealSlotLog(
      name: slotName,
      emoji: slotEmoji,
      items: items,
      totalCalories: planned.calories,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      confidence: 'planned',
    );
  }
}

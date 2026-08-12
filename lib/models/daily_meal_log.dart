class DailyMealLog {
  final String date; // yyyy-MM-dd
  final Map<String, MealSlotLog> customSlots;

  DailyMealLog({
    required this.date,
    this.customSlots = const {},
  });

  int get totalCalories => customSlots.values.fold(0, (sum, slot) => sum + slot.totalCalories);

  double get totalProtein => customSlots.values.fold(0, (sum, slot) => sum + slot.totalProtein);

  double get totalCarbs => customSlots.values.fold(0, (sum, slot) => sum + slot.totalCarbs);

  double get totalFat => customSlots.values.fold(0, (sum, slot) => sum + slot.totalFat);

  int get loggedSlotsCount => customSlots.values.where((s) => s.items.isNotEmpty || s.photoPath != null || s.totalCalories > 0).length;

  factory DailyMealLog.fromJson(Map<String, dynamic> json) {
    final Map<String, MealSlotLog> slots = {};

    // Legacy fields migration
    if (json['breakfast'] != null) slots['breakfast'] = MealSlotLog.fromJson(json['breakfast'] as Map<String, dynamic>);
    if (json['lunch'] != null) slots['lunch'] = MealSlotLog.fromJson(json['lunch'] as Map<String, dynamic>);
    if (json['snack'] != null) slots['snack'] = MealSlotLog.fromJson(json['snack'] as Map<String, dynamic>);
    if (json['dinner'] != null) slots['dinner'] = MealSlotLog.fromJson(json['dinner'] as Map<String, dynamic>);

    // New format
    if (json['customSlots'] != null) {
      final map = json['customSlots'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        slots[entry.key] = MealSlotLog.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return DailyMealLog(
      date: json['date'] as String,
      customSlots: slots,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'customSlots': customSlots.map((k, v) => MapEntry(k, v.toJson())),
      };

  DailyMealLog copyWith({
    Map<String, MealSlotLog>? customSlots,
  }) {
    return DailyMealLog(
      date: date,
      customSlots: customSlots ?? this.customSlots,
    );
  }
}

class MealSlotLog {
  final String? name;
  final String? emoji;
  final String? photoPath;
  final List<MealItemLog> items;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String? confidence; // "high", "medium", "low"

  MealSlotLog({
    this.name,
    this.emoji,
    this.photoPath,
    required this.items,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.confidence,
  });

  factory MealSlotLog.fromJson(Map<String, dynamic> json) {
    return MealSlotLog(
      name: json['name'] as String?,
      emoji: json['emoji'] as String?,
      photoPath: json['photoPath'] as String?,
      items: (json['items'] as List?)
              ?.map((i) => MealItemLog.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalCalories: json['totalCalories'] as int? ?? 0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      confidence: json['confidence'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (emoji != null) 'emoji': emoji,
        if (photoPath != null) 'photoPath': photoPath,
        'items': items.map((i) => i.toJson()).toList(),
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        if (confidence != null) 'confidence': confidence,
      };
}

class MealItemLog {
  final String name;
  final String portion;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  MealItemLog({
    required this.name,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MealItemLog.fromJson(Map<String, dynamic> json) {
    return MealItemLog(
      name: json['name'] as String? ?? 'Unknown',
      portion: json['portion'] as String? ?? '',
      calories: json['calories'] as int? ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'portion': portion,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

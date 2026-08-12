class UserProfile {
  final String name;
  /// Display name for the AI / notes coach (e.g. "Shravan"). Empty → generic "Coach".
  final String coachName;
  final String? photoPath;
  final double height; // in cm
  final double? targetWeight; // in kg
  final bool useKg;
  final int targetCalories;
  final String? activeWorkoutPlan;
  final String? activeMealPlan;
  final List<Map<String, dynamic>> customHabits;
  final List<Map<String, dynamic>> customMealSlots;
  final String? geminiApiKey;
  final bool restTimerSound;
  final bool restTimerVibration;
  final int targetProteinG;
  final int targetCarbsG;
  final int targetFatG;
  final DateTime? planStartDate;
  final int currentPhaseWeek;
  final bool screenTimeEnabled;
  UserProfile({
    this.name = '',
    this.coachName = '',
    this.photoPath,
    this.height = 160,
    this.targetWeight,
    this.useKg = true,
    this.targetCalories = 1250,
    this.activeWorkoutPlan,
    this.activeMealPlan,
    this.customHabits = const [],
    this.customMealSlots = const [
      {'id': 'breakfast', 'name': 'Breakfast', 'emoji': '🍳', 'isDefault': true},
      {'id': 'lunch', 'name': 'Lunch', 'emoji': '🍛', 'isDefault': true},
      {'id': 'snack', 'name': 'Snack', 'emoji': '🍎', 'isDefault': true},
      {'id': 'dinner', 'name': 'Dinner', 'emoji': '🍽️', 'isDefault': true},
    ],
    this.geminiApiKey,
    this.restTimerSound = true,
    this.restTimerVibration = true,
    this.targetProteinG = 80,
    this.targetCarbsG = 120,
    this.targetFatG = 40,
    this.planStartDate,
    this.currentPhaseWeek = 1,
    this.screenTimeEnabled = false,
  });

  /// Title shown on Home coach notes (e.g. "Coach Shravan").
  String get coachDisplayName {
    final n = coachName.trim();
    if (n.isEmpty) return 'Coach';
    if (n.toLowerCase().startsWith('coach ')) return n;
    return 'Coach $n';
  }

  double get heightInMeters => height / 100;

  double? computeBmi(double? weight) {
    if (weight == null || height <= 0) return null;
    return weight / (heightInMeters * heightInMeters);
  }

  String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  double convertWeight(double kg) {
    return useKg ? kg : kg * 2.20462;
  }

  String get weightUnit => useKg ? 'kg' : 'lb';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      coachName: json['coachName'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      height: (json['height'] as num?)?.toDouble() ?? 160,
      targetWeight: (json['targetWeight'] as num?)?.toDouble(),
      useKg: json['useKg'] as bool? ?? true,
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 1250,
      activeWorkoutPlan: json['activeWorkoutPlan'] as String?,
      activeMealPlan: json['activeMealPlan'] as String?,
      customHabits: (json['customHabits'] as List?)
              ?.map((h) => Map<String, dynamic>.from(h as Map))
              .toList() ??
          [],
      customMealSlots: (json['customMealSlots'] as List?)
              ?.map((h) => Map<String, dynamic>.from(h as Map))
              .toList() ??
          [
            {'id': 'breakfast', 'name': 'Breakfast', 'emoji': '🍳', 'isDefault': true},
            {'id': 'lunch', 'name': 'Lunch', 'emoji': '🍛', 'isDefault': true},
            {'id': 'snack', 'name': 'Snack', 'emoji': '🍎', 'isDefault': true},
            {'id': 'dinner', 'name': 'Dinner', 'emoji': '🍽️', 'isDefault': true},
          ],
      geminiApiKey: json['geminiApiKey'] as String?,
      restTimerSound: json['restTimerSound'] as bool? ?? true,
      restTimerVibration: json['restTimerVibration'] as bool? ?? true,
      targetProteinG: (json['targetProteinG'] as num?)?.toInt() ?? 80,
      targetCarbsG: (json['targetCarbsG'] as num?)?.toInt() ?? 120,
      targetFatG: (json['targetFatG'] as num?)?.toInt() ?? 40,
      planStartDate: json['planStartDate'] != null ? DateTime.parse(json['planStartDate'] as String) : null,
      currentPhaseWeek: (json['currentPhaseWeek'] as num?)?.toInt() ?? 1,
      screenTimeEnabled: json['screenTimeEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'coachName': coachName,
        if (photoPath != null) 'photoPath': photoPath,
        'height': height,
        if (targetWeight != null) 'targetWeight': targetWeight,
        'useKg': useKg,
        'targetCalories': targetCalories,
        if (activeWorkoutPlan != null) 'activeWorkoutPlan': activeWorkoutPlan,
        if (activeMealPlan != null) 'activeMealPlan': activeMealPlan,
        'customHabits': customHabits,
        'customMealSlots': customMealSlots,
        'restTimerSound': restTimerSound,
        'restTimerVibration': restTimerVibration,
        'targetProteinG': targetProteinG,
        'targetCarbsG': targetCarbsG,
        'targetFatG': targetFatG,
        if (planStartDate != null) 'planStartDate': planStartDate!.toIso8601String(),
        'currentPhaseWeek': currentPhaseWeek,
        'screenTimeEnabled': screenTimeEnabled,
      };

  UserProfile copyWith({
    String? name,
    String? coachName,
    String? photoPath,
    double? height,
    double? targetWeight,
    bool? useKg,
    int? targetCalories,
    String? activeWorkoutPlan,
    String? activeMealPlan,
    List<Map<String, dynamic>>? customHabits,
    List<Map<String, dynamic>>? customMealSlots,
    String? geminiApiKey,
    bool? restTimerSound,
    bool? restTimerVibration,
    int? targetProteinG,
    int? targetCarbsG,
    int? targetFatG,
    DateTime? planStartDate,
    int? currentPhaseWeek,
    bool? screenTimeEnabled,
    bool clearPhoto = false,
    bool clearPlanStart = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      coachName: coachName ?? this.coachName,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      height: height ?? this.height,
      targetWeight: targetWeight ?? this.targetWeight,
      useKg: useKg ?? this.useKg,
      targetCalories: targetCalories ?? this.targetCalories,
      activeWorkoutPlan: activeWorkoutPlan ?? this.activeWorkoutPlan,
      activeMealPlan: activeMealPlan ?? this.activeMealPlan,
      customHabits: customHabits ?? this.customHabits,
      customMealSlots: customMealSlots ?? this.customMealSlots,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      restTimerSound: restTimerSound ?? this.restTimerSound,
      restTimerVibration: restTimerVibration ?? this.restTimerVibration,
      targetProteinG: targetProteinG ?? this.targetProteinG,
      targetCarbsG: targetCarbsG ?? this.targetCarbsG,
      targetFatG: targetFatG ?? this.targetFatG,
      planStartDate: clearPlanStart ? null : (planStartDate ?? this.planStartDate),
      currentPhaseWeek: currentPhaseWeek ?? this.currentPhaseWeek,
      screenTimeEnabled: screenTimeEnabled ?? this.screenTimeEnabled,
    );
  }
}

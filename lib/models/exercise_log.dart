class ExerciseLog {
  final String date;
  final String exerciseName;
  final List<SetLog> sets;

  ExerciseLog({
    required this.date,
    required this.exerciseName,
    required this.sets,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      date: json['date'] as String,
      exerciseName: json['exerciseName'] as String,
      sets: (json['sets'] as List?)
              ?.map((s) => SetLog.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  double get maxWeight =>
      sets.isEmpty ? 0 : sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  double get totalVolume => sets.fold(0.0, (sum, s) => sum + (s.weight * s.reps));

  String get key => '${date}_$exerciseName';
}

class SetLog {
  final int setNumber;
  final int reps;
  final double weight;

  SetLog({
    required this.setNumber,
    required this.reps,
    this.weight = 0,
  });

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      setNumber: json['setNumber'] as int,
      reps: json['reps'] as int,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'weight': weight,
      };
}

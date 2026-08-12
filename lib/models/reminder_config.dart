import 'package:flutter/material.dart';
import 'dart:convert';

class ReminderConfig {
  final bool habitsEnabled;
  final TimeOfDay habitTime;
  
  final bool workoutsEnabled;
  final TimeOfDay workoutTime;
  
  final bool mealsEnabled;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  
  final bool backupEnabled;
  final int backupDayOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay backupTime;

  final bool photosEnabled;
  final TimeOfDay photoTime;

  ReminderConfig({
    this.habitsEnabled = false,
    this.habitTime = const TimeOfDay(hour: 21, minute: 0),
    this.workoutsEnabled = false,
    this.workoutTime = const TimeOfDay(hour: 7, minute: 0),
    this.mealsEnabled = false,
    this.lunchTime = const TimeOfDay(hour: 13, minute: 0),
    this.dinnerTime = const TimeOfDay(hour: 19, minute: 0),
    this.backupEnabled = false,
    this.backupDayOfWeek = DateTime.sunday,
    this.backupTime = const TimeOfDay(hour: 10, minute: 0),
    this.photosEnabled = true,
    this.photoTime = const TimeOfDay(hour: 10, minute: 0),
  });

  ReminderConfig copyWith({
    bool? habitsEnabled,
    TimeOfDay? habitTime,
    bool? workoutsEnabled,
    TimeOfDay? workoutTime,
    bool? mealsEnabled,
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    bool? backupEnabled,
    int? backupDayOfWeek,
    TimeOfDay? backupTime,
    bool? photosEnabled,
    TimeOfDay? photoTime,
  }) {
    return ReminderConfig(
      habitsEnabled: habitsEnabled ?? this.habitsEnabled,
      habitTime: habitTime ?? this.habitTime,
      workoutsEnabled: workoutsEnabled ?? this.workoutsEnabled,
      workoutTime: workoutTime ?? this.workoutTime,
      mealsEnabled: mealsEnabled ?? this.mealsEnabled,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupDayOfWeek: backupDayOfWeek ?? this.backupDayOfWeek,
      backupTime: backupTime ?? this.backupTime,
      photosEnabled: photosEnabled ?? this.photosEnabled,
      photoTime: photoTime ?? this.photoTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'habitsEnabled': habitsEnabled,
      'habitTime': '${habitTime.hour}:${habitTime.minute}',
      'workoutsEnabled': workoutsEnabled,
      'workoutTime': '${workoutTime.hour}:${workoutTime.minute}',
      'mealsEnabled': mealsEnabled,
      'lunchTime': '${lunchTime.hour}:${lunchTime.minute}',
      'dinnerTime': '${dinnerTime.hour}:${dinnerTime.minute}',
      'backupEnabled': backupEnabled,
      'backupDayOfWeek': backupDayOfWeek,
      'backupTime': '${backupTime.hour}:${backupTime.minute}',
      'photosEnabled': photosEnabled,
      'photoTime': '${photoTime.hour}:${photoTime.minute}',
    };
  }

  factory ReminderConfig.fromMap(Map<String, dynamic> map) {
    TimeOfDay parseTime(String? timeStr, TimeOfDay defaultTime) {
      if (timeStr == null || !timeStr.contains(':')) return defaultTime;
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? defaultTime.hour,
          minute: int.tryParse(parts[1]) ?? defaultTime.minute,
        );
      }
      return defaultTime;
    }

    return ReminderConfig(
      habitsEnabled: map['habitsEnabled'] ?? false,
      habitTime: parseTime(map['habitTime'], const TimeOfDay(hour: 21, minute: 0)),
      workoutsEnabled: map['workoutsEnabled'] ?? false,
      workoutTime: parseTime(map['workoutTime'], const TimeOfDay(hour: 7, minute: 0)),
      mealsEnabled: map['mealsEnabled'] ?? false,
      lunchTime: parseTime(map['lunchTime'], const TimeOfDay(hour: 13, minute: 0)),
      dinnerTime: parseTime(map['dinnerTime'], const TimeOfDay(hour: 19, minute: 0)),
      backupEnabled: map['backupEnabled'] ?? false,
      backupDayOfWeek: map['backupDayOfWeek'] ?? DateTime.sunday,
      backupTime: parseTime(map['backupTime'], const TimeOfDay(hour: 10, minute: 0)),
      photosEnabled: map['photosEnabled'] ?? true,
      photoTime: parseTime(map['photoTime'], const TimeOfDay(hour: 10, minute: 0)),
    );
  }

  String toJson() => json.encode(toMap());

  factory ReminderConfig.fromJson(String source) => ReminderConfig.fromMap(json.decode(source));
}

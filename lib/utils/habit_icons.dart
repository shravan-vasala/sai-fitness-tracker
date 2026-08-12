import 'package:flutter/material.dart';

/// Habit icons are Material [IconData], stored as string keys.
/// Legacy emoji values still resolve for existing saved habits.
class HabitIcons {
  HabitIcons._();

  static const List<({String id, IconData icon})> options = [
    (id: 'check', icon: Icons.check_circle_outline_rounded),
    (id: 'bedtime', icon: Icons.dark_mode_outlined),
    (id: 'walk', icon: Icons.directions_walk_outlined),
    (id: 'water', icon: Icons.water_drop_outlined),
    (id: 'mind', icon: Icons.self_improvement_outlined),
    (id: 'book', icon: Icons.menu_book_outlined),
    (id: 'meds', icon: Icons.medication_outlined),
    (id: 'food', icon: Icons.restaurant_outlined),
    (id: 'train', icon: Icons.fitness_center_outlined),
    (id: 'run', icon: Icons.directions_run_outlined),
    (id: 'smoke_free', icon: Icons.smoke_free_outlined),
    (id: 'greens', icon: Icons.eco_outlined),
  ];

  static IconData resolve(String keyOrEmoji) {
    switch (keyOrEmoji) {
      case '😴':
      case 'bedtime':
        return Icons.dark_mode_outlined;
      case '🚶':
      case 'walk':
        return Icons.directions_walk_outlined;
      case '🏃':
      case 'run':
        return Icons.directions_run_outlined;
      case '💧':
      case 'water':
        return Icons.water_drop_outlined;
      case '✅':
      case 'check':
        return Icons.check_circle_outline_rounded;
      case '🧘':
      case 'mind':
        return Icons.self_improvement_outlined;
      case '📚':
      case 'book':
        return Icons.menu_book_outlined;
      case '💊':
      case 'meds':
        return Icons.medication_outlined;
      case '🍎':
      case 'food':
        return Icons.restaurant_outlined;
      case '🏋️':
      case 'train':
        return Icons.fitness_center_outlined;
      case '🚭':
      case 'smoke_free':
        return Icons.smoke_free_outlined;
      case '🥦':
      case 'greens':
        return Icons.eco_outlined;
      default:
        for (final o in options) {
          if (o.id == keyOrEmoji) return o.icon;
        }
        return Icons.check_circle_outline_rounded;
    }
  }

  /// Prefer storing stable keys when saving.
  static String normalize(String keyOrEmoji) {
    switch (keyOrEmoji) {
      case '😴':
        return 'bedtime';
      case '🚶':
        return 'walk';
      case '🏃':
        return 'run';
      case '💧':
        return 'water';
      case '✅':
        return 'check';
      case '🧘':
        return 'mind';
      case '📚':
        return 'book';
      case '💊':
        return 'meds';
      case '🍎':
        return 'food';
      case '🏋️':
        return 'train';
      case '🚭':
        return 'smoke_free';
      case '🥦':
        return 'greens';
      default:
        for (final o in options) {
          if (o.id == keyOrEmoji) return o.id;
        }
        return 'check';
    }
  }
}

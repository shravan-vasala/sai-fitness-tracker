import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_config.dart';
import '../services/notification_service.dart';
import 'app_providers.dart';

class RemindersNotifier extends StateNotifier<ReminderConfig> {
  final SharedPreferences _prefs;
  final NotificationService _notificationService;
  final Ref _ref;

  RemindersNotifier(this._prefs, this._notificationService, this._ref) : super(ReminderConfig()) {
    _load();
  }

  static final _key = 'reminder_config';

  void _load() {
    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      state = ReminderConfig.fromJson(jsonStr);
    }
  }

  Future<void> updateConfig(ReminderConfig newConfig) async {
    state = newConfig;
    await _prefs.setString(_key, newConfig.toJson());
    await _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    // Request permission if enabling anything
    if (state.habitsEnabled || state.workoutsEnabled || state.mealsEnabled || state.backupEnabled || state.photosEnabled) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        // Fallback: If not granted, we probably shouldn't keep them enabled in UI
        // But we'll let it be for now and let the user see them toggled but not firing.
      }
    }

    await _notificationService.cancelAll();

    if (state.habitsEnabled) {
      await _notificationService.scheduleHabitReminder(state.habitTime);
    }

    if (state.workoutsEnabled) {
      final workoutPlan = _ref.read(workoutPlanProvider);
      if (workoutPlan != null) {
        // Convert active days to list of ints (1=Monday, 7=Sunday)
        // workoutPlan.days has items. Index 0 is Monday (usually)
        List<int> activeDays = [];
        for (final day in workoutPlan.days) {
          if (day.sections.isNotEmpty && day.dayId != 'Rest') {
            final wday = day.weekday;
            if (wday != null) activeDays.add(wday);
          }
        }
        if (activeDays.isNotEmpty) {
          await _notificationService.scheduleWorkoutReminders(activeDays, state.workoutTime);
        }
      }
    }

    if (state.mealsEnabled) {
      await _notificationService.scheduleMealReminders(state.lunchTime, state.dinnerTime);
    }

    if (state.backupEnabled) {
      await _notificationService.scheduleBackupReminder(state.backupDayOfWeek, state.backupTime);
    }

    if (state.photosEnabled) {
      final mediaRepo = _ref.read(mediaRepoProvider);
      final allPhotos = mediaRepo.getAllProgressPhotosDetailed();
      DateTime? lastPhotoDate;
      if (allPhotos.isNotEmpty) {
        // Since getAllProgressPhotos() sorts descending, the first one might be the latest.
        // Wait, getAllProgressPhotosDetailed() relies on getAllProgressPhotos() which is sorted by date descending.
        // So the first element should be the latest date.
        try {
          lastPhotoDate = DateTime.parse(allPhotos.first.date);
        } catch (_) {}
      }
      await _notificationService.schedulePhotoReminder(state.photoTime, lastPhotoDate);
    }
  }

  // Called on app boot from main.dart
  Future<void> initializeNotifications() async {
    await _syncNotifications();
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, ReminderConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return RemindersNotifier(prefs, notificationService, ref);
});


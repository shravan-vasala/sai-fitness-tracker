import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // Fallback if platform timezone cannot be determined
      tz.setLocalLocation(tz.getLocation('America/Detroit'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      final bool? exactGranted = await androidImplementation.requestExactAlarmsPermission();
      return (granted ?? false) && (exactGranted ?? false);
    }
    return false;
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> scheduleHabitReminder(TimeOfDay time) async {
    await _scheduleDaily(
      id: 10,
      title: 'Habit Reminder',
      body: 'Log your habits for today!',
      time: time,
    );
  }

  Future<void> scheduleMealReminders(TimeOfDay lunchTime, TimeOfDay dinnerTime) async {
    await _scheduleDaily(
      id: 20,
      title: 'Lunch Logging',
      body: 'Time to track your lunch!',
      time: lunchTime,
    );
    await _scheduleDaily(
      id: 21,
      title: 'Dinner Logging',
      body: 'Time to track your dinner!',
      time: dinnerTime,
    );
  }

  Future<void> scheduleBackupReminder(int dayOfWeek, TimeOfDay time) async {
    await _scheduleWeekly(
      id: 30,
      title: 'Weekly Backup',
      body: 'Time for your weekly TruFit backup!',
      dayOfWeek: dayOfWeek,
      time: time,
    );
  }

  Future<void> scheduleWorkoutReminders(List<int> workoutDaysOfWeek, TimeOfDay time) async {
    // Cancel old workout reminders (ids 40-46)
    for (int i = 0; i < 7; i++) {
      await _notificationsPlugin.cancel(40 + i);
    }

    for (final day in workoutDaysOfWeek) {
      await _scheduleWeekly(
        id: 40 + day,
        title: 'Workout Today',
        body: 'Time to crush your workout!',
        dayOfWeek: day,
        time: time,
      );
    }
  }

  Future<void> schedulePhotoReminder(TimeOfDay time, DateTime? lastPhotoDate) async {
    // ID 50 for photo reminder
    await _notificationsPlugin.cancel(50);
    
    // If last photo is null, or it's been more than 14 days, remind them today/tomorrow
    final now = DateTime.now();
    bool needsNudge = false;
    
    if (lastPhotoDate == null) {
      needsNudge = true;
    } else {
      if (now.difference(lastPhotoDate).inDays >= 14) {
        needsNudge = true;
      }
    }

    if (needsNudge) {
      // Schedule a daily nudge until they take a photo
      await _scheduleDaily(
        id: 50,
        title: 'Time for a Progress Photo',
        body: 'It\'s been a while! Update your physique pictures.',
        time: time,
      );
    } else {
      // Schedule exactly 14 days from the last photo date at the preferred time
      final scheduledDay = lastPhotoDate!.add(const Duration(days: 14));
      var scheduledDate = tz.TZDateTime(tz.local, scheduledDay.year, scheduledDay.month, scheduledDay.day, time.hour, time.minute);
      
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
         // Fallback if we somehow got here
         scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        50,
        'Progress Photo Due',
        'It\'s been 2 weeks! Time for a new progress picture.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_channel',
            'Weekly Reminders',
            channelDescription: 'Weekly reminders for workouts and backups',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Daily Reminders',
          channelDescription: 'Daily reminders for habits and meals',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required TimeOfDay time,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeeklyTime(dayOfWeek, time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_channel',
          'Weekly Reminders',
          channelDescription: 'Weekly reminders for workouts and backups',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeeklyTime(int dayOfWeek, TimeOfDay time) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

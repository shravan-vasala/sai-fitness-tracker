import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

final screenTimeServiceProvider = Provider<ScreenTimeService>((ref) {
  return ScreenTimeService();
});

class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.trufit.trufit_bodamma/screentime');

  /// Returns true if the app has PACKAGE_USAGE_STATS permission
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool hasPermission = await _channel.invokeMethod('checkPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('Error checking screen time permission: $e');
      return false;
    }
  }

  /// Opens the device settings page for Usage Access
  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    
    // Attempt to launch the exact intent via Kotlin
    try {
       await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      debugPrint('Failed to open usage settings via native channel: $e');
      openAppSettings();
    }
  }

  /// Fetches screen time (totalTimeInForeground) in minutes for the current day
  /// Returns 0 if permission is not granted or platform is not Android
  Future<int> getScreenTimeForToday() async {
    if (!Platform.isAndroid) return 0;
    try {
      final int minutes = await _channel.invokeMethod('getScreenTime');
      return minutes;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint('Screen time permission denied.');
      } else {
        debugPrint('Failed to get screen time: ${e.message}');
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting screen time: $e');
      return 0;
    }
  }
}

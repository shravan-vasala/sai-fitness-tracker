import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import 'app_providers.dart'; // to get profileProvider for settings

String kTimerEndTimeKey = 'rest_timer_end_time';
String kTimerRemainingKey = 'rest_timer_remaining';
String kTimerIsPausedKey = 'rest_timer_is_paused';
String kTimerExerciseKey = 'rest_timer_exercise';

class RestTimerState {
  final int remainingSeconds;
  final bool isActive;
  final bool isPaused;
  final String? exerciseName;

  RestTimerState({
    required this.remainingSeconds,
    this.isActive = false,
    this.isPaused = false,
    this.exerciseName,
  });

  RestTimerState copyWith({
    int? remainingSeconds,
    bool? isActive,
    bool? isPaused,
    String? exerciseName,
  }) {
    return RestTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      exerciseName: exerciseName ?? this.exerciseName,
    );
  }
}

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  final Ref _ref;
  Timer? _timer;
  int? _targetEndTimeEpoch;

  RestTimerNotifier(this._ref) : super(RestTimerState(remainingSeconds: 0)) {
    _loadPersistedTimer();
  }

  Future<void> _loadPersistedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final isPaused = prefs.getBool(kTimerIsPausedKey) ?? false;
    final exerciseName = prefs.getString(kTimerExerciseKey);

    if (isPaused) {
      final remaining = prefs.getInt(kTimerRemainingKey);
      if (remaining != null && remaining > 0) {
        state = RestTimerState(
          remainingSeconds: remaining,
          isActive: true,
          isPaused: true,
          exerciseName: exerciseName,
        );
      }
    } else {
      final endTimeEpoch = prefs.getInt(kTimerEndTimeKey);
      if (endTimeEpoch != null) {
        final remaining = (endTimeEpoch - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
        if (remaining > 0) {
          _targetEndTimeEpoch = endTimeEpoch;
          state = RestTimerState(
            remainingSeconds: remaining,
            isActive: true,
            isPaused: false,
            exerciseName: exerciseName,
          );
          _startInternalTimer();
        } else {
          // It expired while app was closed
          _clearPersistedTimer();
        }
      }
    }
  }

  Future<void> _persistTimer() async {
    final prefs = await SharedPreferences.getInstance();
    if (!state.isActive) {
      await _clearPersistedTimer();
      return;
    }
    
    if (state.exerciseName != null) {
      await prefs.setString(kTimerExerciseKey, state.exerciseName!);
    } else {
      await prefs.remove(kTimerExerciseKey);
    }
    
    await prefs.setBool(kTimerIsPausedKey, state.isPaused);
    if (state.isPaused) {
      await prefs.setInt(kTimerRemainingKey, state.remainingSeconds);
      await prefs.remove(kTimerEndTimeKey);
    } else {
      await prefs.setInt(kTimerEndTimeKey, _targetEndTimeEpoch ?? 0);
      await prefs.remove(kTimerRemainingKey);
    }
  }

  Future<void> _clearPersistedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTimerEndTimeKey);
    await prefs.remove(kTimerRemainingKey);
    await prefs.remove(kTimerIsPausedKey);
    await prefs.remove(kTimerExerciseKey);
  }

  void startTimer(int seconds, {String? exerciseName}) {
    _timer?.cancel();
    _targetEndTimeEpoch = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    state = RestTimerState(
      remainingSeconds: seconds,
      isActive: true,
      isPaused: false,
      exerciseName: exerciseName,
    );
    _persistTimer();
    _startInternalTimer();
  }

  void _startInternalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_targetEndTimeEpoch != null) {
        final remaining = (_targetEndTimeEpoch! - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
        if (remaining > 0) {
          state = state.copyWith(remainingSeconds: remaining);
        } else {
          _onTimerComplete();
        }
      }
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    final completedExercise = state.exerciseName;
    state = RestTimerState(remainingSeconds: 0, isActive: false, isPaused: false);
    _clearPersistedTimer();

    // Trigger feedback based on profile settings
    final profile = _ref.read(profileProvider);
    if (profile.restTimerVibration) {
      HapticFeedback.heavyImpact();
    }
    if (profile.restTimerSound) {
      SystemSound.play(SystemSoundType.alert);
    }

    // Show Snackbar if context is available
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.timer_off_rounded, color: context.colors.onPrimary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rest Complete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (completedExercise != null)
                      Text(
                        'Time for $completedExercise',
                        style: TextStyle(fontSize: 12, color: context.colors.onPrimary.withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: context.colors.orange,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void stopTimer() {
    _timer?.cancel();
    state = state.copyWith(isActive: false, isPaused: false, remainingSeconds: 0);
    _clearPersistedTimer();
  }

  void pauseTimer() {
    if (state.isActive && !state.isPaused) {
      _timer?.cancel();
      state = state.copyWith(isPaused: true);
      _persistTimer();
    }
  }

  void resumeTimer() {
    if (state.isActive && state.isPaused) {
      _targetEndTimeEpoch = DateTime.now().millisecondsSinceEpoch + (state.remainingSeconds * 1000);
      state = state.copyWith(isPaused: false);
      _persistTimer();
      _startInternalTimer();
    }
  }

  void addSeconds(int seconds) {
    if (state.isActive) {
      final newRemaining = state.remainingSeconds + seconds;
      if (state.isPaused) {
        state = state.copyWith(remainingSeconds: newRemaining);
      } else {
        _targetEndTimeEpoch = (_targetEndTimeEpoch ?? DateTime.now().millisecondsSinceEpoch) + (seconds * 1000);
        state = state.copyWith(remainingSeconds: newRemaining);
      }
      _persistTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final restTimerProvider = StateNotifierProvider<RestTimerNotifier, RestTimerState>((ref) {
  return RestTimerNotifier(ref);
});

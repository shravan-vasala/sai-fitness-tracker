import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';

class RestTimerLabel extends ConsumerWidget {
  const RestTimerLabel({super.key, required this.seconds, required this.exerciseName});

  final int seconds;
  final String exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seconds <= 0) return SizedBox.shrink();

    final timerState = ref.watch(restTimerProvider);
    final isActive = timerState.isActive && timerState.exerciseName == exerciseName;
    final displaySeconds = isActive ? timerState.remainingSeconds : seconds;


    final display = displaySeconds >= 60
        ? '${displaySeconds ~/ 60} MIN${displaySeconds % 60 > 0 ? ' ${displaySeconds % 60} SEC' : ''}'
        : '$displaySeconds SEC';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: isActive ? context.colors.orange : context.colors.border),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: isActive ? context.colors.orange : context.colors.textLight,
                ),
                SizedBox(width: 4),
                Text(
                  isActive ? 'RESTING FOR $display' : 'REST FOR $display AFTER SET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? context.colors.orange : context.colors.textLight,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(height: 1, color: isActive ? context.colors.orange : context.colors.border),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/primary_button.dart';

/// Calm one-shot celebration when habits + meals + workout buckets are full.
Future<void> maybeShowDayCompleteSheet(BuildContext context, WidgetRef ref) async {
  final score = ref.read(dailyScoreProvider);
  if (!score.isPrimaryComplete || score.isFutureDate) return;

  final dateStr = ref.read(dateStringProvider);
  final todayStr = DateTime.now().toIso8601String().substring(0, 10);
  if (dateStr != todayStr) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final key = 'day_complete_shown_$dateStr';
  if (prefs.getBool(key) == true) return;

  await prefs.setBool(key, true);
  if (!context.mounted) return;

  await showAppBottomSheet<void>(
    context: context,
    builder: (ctx) => const DayCompleteSheet(),
  );
}

class DayCompleteSheet extends ConsumerWidget {
  const DayCompleteSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider.select((p) => p.name));
    final score = ref.watch(dailyScoreProvider);
    final greetName = name.trim().isEmpty ? 'you' : name.trim();

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: context.colors.green,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Day complete, $greetName',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Habits, meals, and workout are done. Score ${score.totalScore} — nice consistency.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Keep going',
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

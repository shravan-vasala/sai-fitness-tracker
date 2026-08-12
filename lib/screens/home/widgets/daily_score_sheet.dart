import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';

class DailyScoreSheet extends ConsumerWidget {
  const DailyScoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreData = ref.watch(dailyScoreProvider);

    Color scoreColor = context.colors.green;
    if (scoreData.totalScore < 50) {
      scoreColor = context.colors.red;
    } else if (scoreData.totalScore < 80) {
      scoreColor = context.colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Score',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.colors.textLight),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (scoreData.isFutureDate)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'Data not available for future dates.',
                  style: TextStyle(color: context.colors.textLight, fontSize: 16),
                ),
              ),
            )
          else ...[
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${scoreData.totalScore}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      'out of 100',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scoreColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Score Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.textDark,
              ),
            ),
            SizedBox(height: 16),
            _buildScoreRow(
              context: context,
              label: 'Habits',
              score: scoreData.habitsScore,
              max: scoreData.habitsMax,
              icon: Icons.check_circle_outline_rounded,
              color: context.colors.primary,
            ),
            _buildScoreRow(
              context: context,
              label: 'Workouts',
              score: scoreData.workoutsScore,
              max: scoreData.workoutsMax,
              icon: Icons.fitness_center_rounded,
              color: context.colors.orange,
            ),
            _buildScoreRow(
              context: context,
              label: 'Meals',
              score: scoreData.mealsScore,
              max: scoreData.mealsMax,
              icon: Icons.restaurant_rounded,
              color: context.colors.green,
            ),
            if (scoreData.stepsMax > 0)
              _buildScoreRow(
                context: context,
                label: 'Steps',
                score: scoreData.stepsScore,
                max: scoreData.stepsMax,
                icon: Icons.directions_walk_rounded,
                color: context.colors.mintIcon,
              ),
            if (scoreData.waterMax > 0)
              _buildScoreRow(
                context: context,
                label: 'Water',
                score: scoreData.waterScore,
                max: scoreData.waterMax,
                icon: Icons.water_drop_rounded,
                color: context.colors.textDark,
              ),
            SizedBox(height: 24),
            Text(
              'Your final score is normalized based on your active goals for the day.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textLight,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreRow({
    required BuildContext context,
    required String label,
    required double score,
    required double max,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textDark,
              ),
            ),
          ),
          Text(
            '${score == score.toInt() ? score.toInt().toString() : score.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

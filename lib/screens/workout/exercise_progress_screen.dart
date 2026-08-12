import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../progress/widgets/shared_chart_card.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/exercise_log.dart';
import '../../models/exercise_pr.dart';

class ExerciseProgressScreen extends ConsumerWidget {
  const ExerciseProgressScreen({super.key, required this.exerciseName});

  final String exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(exerciseHistoryProvider(exerciseName));
    
    final plan = ref.watch(workoutPlanProvider);
    String displayTitle = exerciseName;
    if (plan != null) {
      for (final day in plan.days) {
        for (final sec in day.sections) {
          for (final ex in sec.exercises) {
            if (ex.name == exerciseName) {
              displayTitle = ex.displayName ?? exerciseName;
              break;
            }
          }
        }
      }
    }

    // Sort logs by date to ensure proper charting
    final sortedLogs = List<ExerciseLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));

    // Prepare Max Weight Data and Stats
    final List<ChartDataPoint> maxWeightData = sortedLogs
        .map((l) => ChartDataPoint(DateTime.parse(l.date), l.maxWeight))
        .toList();

    List<String> maxWeightStats = [];
    if (sortedLogs.isNotEmpty) {
      final weights = sortedLogs.map((l) => l.maxWeight).toList();
      final max = weights.reduce((a, b) => a > b ? a : b);
      final last = weights.last;
      final avg = weights.reduce((a, b) => a + b) / weights.length;
      maxWeightStats = [
        '${max.toStringAsFixed(1)} kg',
        '${last.toStringAsFixed(1)} kg',
        '${avg.toStringAsFixed(1)} kg',
      ];
    }

    // Prepare Total Volume Data and Stats
    final List<ChartDataPoint> totalVolumeData = sortedLogs
        .map((l) => ChartDataPoint(DateTime.parse(l.date), l.totalVolume))
        .toList();

    List<String> totalVolumeStats = [];
    if (sortedLogs.isNotEmpty) {
      final vols = sortedLogs.map((l) => l.totalVolume).toList();
      final max = vols.reduce((a, b) => a > b ? a : b);
      final last = vols.last;
      final avg = vols.reduce((a, b) => a + b) / vols.length;
      totalVolumeStats = [
        '${max.toStringAsFixed(1)} kg',
        '${last.toStringAsFixed(1)} kg',
        '${avg.toStringAsFixed(1)} kg',
      ];
    }

    final startDate = sortedLogs.isNotEmpty ? DateTime.parse(sortedLogs.first.date) : DateTime.now();
    final endDate = DateTime.now();

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text(displayTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: sortedLogs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 64,
                    color: context.colors.textLight.withValues(alpha: 0.4),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No data logged yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMedium,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Log exercise data to see your progress',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textLight,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (ref.watch(exerciseLogRepoProvider).getPr(exerciseName) != null) ...[
                        _PrSummary(pr: ref.watch(exerciseLogRepoProvider).getPr(exerciseName)!),
                        const SizedBox(height: 20),
                      ],
                      SharedChartCard(
                        title: 'Max Weight',
                        data: maxWeightData,
                        statLabels: const ['BEST', 'LAST', 'AVERAGE'],
                        statValues: maxWeightStats,
                        timeFormat: ChartTimeFormat.allTime,
                        startDate: startDate,
                        endDate: endDate,
                        emptyMessage: 'No data logged yet',
                      ),
                      const SizedBox(height: 16),
                      SharedChartCard(
                        title: 'Total Volume',
                        data: totalVolumeData,
                        statLabels: const ['BEST', 'LAST', 'AVERAGE'],
                        statValues: totalVolumeStats,
                        timeFormat: ChartTimeFormat.allTime,
                        startDate: startDate,
                        endDate: endDate,
                        emptyMessage: 'No data logged yet',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'HISTORY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textLight,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _HistoryCard(log: sortedLogs[sortedLogs.length - 1 - index]);
                      },
                      childCount: sortedLogs.length,
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 20),
                ),
              ],
            ),
    );
  }
}

class _PrSummary extends StatelessWidget {
  final ExercisePr pr;
  const _PrSummary({required this.pr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFD700).withValues(alpha: 0.1),
        border: Border.all(color: Color(0xFFFFD700).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFB8860B), size: 24),
              SizedBox(width: 8),
              Text(
                'PERSONAL RECORDS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFFB8860B),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (pr.maxWeight > 0)
            _buildPrRow('Max Weight', '${pr.maxWeight}kg × ${pr.maxWeightReps}'),
          if (pr.maxReps > 0 && (pr.maxWeight == 0 || pr.maxReps > pr.maxWeightReps))
            _buildPrRow('Max Reps', '${pr.maxReps} reps @ ${pr.maxRepsWeight}kg'),
          if (pr.estimated1RM > 0)
            _buildPrRow('Est. 1RM', '${pr.estimated1RM.toStringAsFixed(1)}kg'),
          if (pr.maxVolume > 0)
            _buildPrRow('Max Volume', '${pr.maxVolume}kg'),
        ],
      ),
    );
  }

  Widget _buildPrRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Color(0xFF8B6508))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8B6508))),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.log});

  final ExerciseLog log;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(log.date));
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  log.sets.map((s) => '${s.reps}×${s.weight}kg').join(' | '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${log.totalVolume.toStringAsFixed(0)} kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
              Text(
                'volume',
                style: TextStyle(fontSize: 11, color: context.colors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

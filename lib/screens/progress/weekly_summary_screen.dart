import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../providers/weekly_summary_provider.dart';
import '../../providers/app_providers.dart';
import 'package:intl/intl.dart';

class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    
    // Get week bounds for title
    final weekday = selectedDate.weekday;
    final startOfWeek = selectedDate.subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final titleText = '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}';

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text('Weekly Summary'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              // ── Score Hero Card ──
              _ScoreHeroCard(score: summary.weekScore),
              SizedBox(height: 24),
              
              // ── Habits Chart ──
              if (summary.habitCompletionRate > 0)
                _HabitChartCard(rates: summary.dailyHabitRates),
              if (summary.habitCompletionRate > 0)
                SizedBox(height: 16),

              // ── Grid Stats ──
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1, // slightly wide cards
                children: [
                  _StatCard(
                    title: 'Workouts',
                    icon: Icons.fitness_center_rounded,
                    primaryValue: '${summary.workoutsCompleted}/${summary.workoutsTotal}',
                    subtitle: 'Sections Done',
                  ),
                  _StatCard(
                    title: 'Habits',
                    icon: Icons.checklist_rounded,
                    primaryValue: '${(summary.habitCompletionRate * 100).toInt()}%',
                    subtitle: summary.bestHabit != null ? 'Best: ${summary.bestHabit}' : 'Completion',
                  ),
                  _StatCard(
                    title: 'Steps',
                    icon: Icons.directions_walk_rounded,
                    primaryValue: '${summary.avgSteps}',
                    subtitle: 'Avg / day (Best: ${summary.bestSteps})',
                  ),
                  _StatCard(
                    title: 'Sleep',
                    icon: Icons.nightlight_round,
                    primaryValue: '${summary.avgSleep.toStringAsFixed(1)}h',
                    subtitle: 'Avg / night',
                    tertiaryText: summary.nightsUnder7h > 0 ? '${summary.nightsUnder7h} nights < 7h' : null,
                  ),
                  _StatCard(
                    title: 'Nutrition',
                    icon: Icons.local_fire_department_rounded,
                    primaryValue: '${summary.avgCalories}',
                    subtitle: 'Avg kcal / day',
                    tertiaryText: '${summary.daysOverCalories} days over limit',
                  ),
                  _StatCard(
                    title: 'Weight',
                    icon: Icons.monitor_weight_rounded,
                    primaryValue: summary.weightDelta != 0 
                      ? (summary.weightDelta > 0 ? '+${summary.weightDelta.toStringAsFixed(1)}' : summary.weightDelta.toStringAsFixed(1))
                      : '-',
                    subtitle: 'Delta this week',
                  ),
                ],
              ),
              SizedBox(height: 32),
              
              // ── Share Button ──
              ElevatedButton.icon(
                onPressed: () {
                  final text = summary.generateShareText();
                  Share.share(text);
                },
                icon: Icon(Icons.ios_share_rounded),
                label: Text('Share Summary'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHeroCard extends StatelessWidget {
  final int score;
  const _ScoreHeroCard({required this.score});

  @override
  Widget build(BuildContext context) {
    String message;
    if (score >= 90) {
      message = 'Crushing it!';
    } else if (score >= 70) {
      message = 'Great week!';
    } else if (score >= 50) {
      message = 'Good effort!';
    } else {
      message = 'Room to grow';
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: context.colors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Week Score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: context.colors.onPrimary,
              height: 1.0,
            ),
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitChartCard extends StatelessWidget {
  final List<double> rates;
  const _HabitChartCard({required this.rates});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: context.colors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Daily Habits',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[i],
                            style: TextStyle(
                              color: context.colors.textMedium,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rates[i],
                        color: context.colors.primary,
                        width: 14,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 1.0,
                          color: context.colors.lavender,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String primaryValue;
  final String subtitle;
  final String? tertiaryText;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.primaryValue,
    required this.subtitle,
    this.tertiaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: context.colors.primary),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Spacer(),
          Text(
            primaryValue,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.colors.textDark,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (tertiaryText != null) ...[
            SizedBox(height: 2),
            Text(
              tertiaryText!,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.red,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../widgets/surface_card.dart';
import 'shared_chart_card.dart';

class MetricOverviewCard extends StatelessWidget {
  const MetricOverviewCard({
    super.key,
    required this.icon,
    required this.title,
    required this.valueText,
    required this.data,
    required this.startDate,
    required this.endDate,
    required this.onTap,
    this.subtitle,
    this.isCount = false,
  });

  final IconData icon;
  final String title;
  final String valueText;
  /// e.g. "avg this period" or "−0.4 kg vs start"
  final String? subtitle;
  final List<ChartDataPoint> data;
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onTap;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      elevation: SurfaceCardElevation.nested,
      borderRadius: kCardRadius,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textDark,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.textLight,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: data.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No data this period',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textLight,
                      ),
                    ),
                  )
                : _MiniSparkline(
                    data: data,
                    startDate: startDate,
                    endDate: endDate,
                    isCount: isCount,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.data,
    required this.startDate,
    required this.endDate,
    required this.isCount,
  });

  final List<ChartDataPoint> data;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCount;

  List<List<FlSpot>> _segments(List<FlSpot> sorted) {
    if (sorted.isEmpty) return const [];
    final out = <List<FlSpot>>[];
    var cur = <FlSpot>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].x - sorted[i - 1].x > 1.5) {
        out.add(cur);
        cur = <FlSpot>[sorted[i]];
      } else {
        cur.add(sorted[i]);
      }
    }
    out.add(cur);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = data.toList()..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted
        .where((d) => !isCount || d.value > 0)
        .map(
          (d) => FlSpot(
            d.date.difference(startDate).inDays.toDouble(),
            d.value,
          ),
        )
        .toList();

    if (spots.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No data this period',
          style: TextStyle(fontSize: 12, color: context.colors.textLight),
        ),
      );
    }

    double minY = spots.map((s) => s.y).reduce(min);
    double maxY = spots.map((s) => s.y).reduce(max);
    if (minY == maxY) {
      minY = isCount ? 0 : minY - 1;
      maxY = maxY + 1;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }
    if (isCount && minY < 0) minY = 0;

    final maxX =
        endDate.difference(startDate).inDays.toDouble().clamp(1.0, 9999.0);
    final showDots = spots.length <= 14;
    final primary = context.colors.primary;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: [
          for (final segment in _segments(spots))
            LineChartBarData(
              spots: segment,
              isCurved: spots.length > 2 && segment.length > 2,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: primary,
              barWidth: 2,
              dotData: FlDotData(show: showDots || segment.length == 1),
              belowBarData: BarAreaData(
                show: segment.length > 1,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primary.withValues(alpha: 0.28),
                    primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
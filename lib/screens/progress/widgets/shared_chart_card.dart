import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';

enum ChartTimeFormat { weekly, monthly, sixMonths, allTime }

class ChartDataPoint {
  final DateTime date;
  final double value;
  ChartDataPoint(this.date, this.value);
}

class SharedChartCard extends StatelessWidget {
  const SharedChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.startDate,
    required this.endDate,
    this.isSteps = false,
    this.isCalories = false,
    this.isProtein = false,
    this.showKgLbToggle = false,
    this.useKg = true,
    this.onToggleUnit,
    required this.statLabels,
    required this.statValues,
    this.timeFormat = ChartTimeFormat.monthly,
    this.emptyMessage = 'No data available for this period',
    this.targetValue,
    this.onPointLongPress,
  });

  final String title;
  final List<ChartDataPoint> data;
  final DateTime startDate;
  final DateTime endDate;
  final bool isSteps;
  final bool isCalories;
  final bool isProtein;
  final bool showKgLbToggle;
  final bool useKg;
  final VoidCallback? onToggleUnit;
  final List<String> statLabels;
  final List<String> statValues;
  final ChartTimeFormat timeFormat;
  final String emptyMessage;
  final double? targetValue;
  final void Function(DateTime date, double value)? onPointLongPress;

  bool get _isCount => isSteps || isCalories || isProtein;

  /// Daily totals read clearer as bars; body metrics stay as lines.
  bool get _useBars => _isCount;

  String _unitSuffix() {
    if (isSteps) return ' steps';
    if (isCalories) return ' kcal';
    if (isProtein) return 'g';
    if (showKgLbToggle) return useKg ? ' kg' : ' lb';
    if (title.toLowerCase().contains('sleep')) return 'h';
    if (title.toLowerCase().contains('body fat')) return '%';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  Spacer(),
                  if (showKgLbToggle)
                    GestureDetector(
                      onTap: onToggleUnit,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: Text(
                          useKg ? 'KG' : 'LB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: data.isEmpty
                    ? Center(
                        child: Text(
                          emptyMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _useBars
                        ? _buildBarChart(context)
                        : _buildLineChart(context),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (statLabels.isNotEmpty && statValues.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(kCardRadius),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                statLabels.length,
                (index) => Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              statLabels[index],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textLight,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              statValues[index],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      if (index < statLabels.length - 1)
                        Container(
                          width: 1,
                          height: 30,
                          color: context.colors.border,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double get _maxXValue =>
      endDate.difference(startDate).inDays.toDouble().clamp(1.0, 9999.0);

  (double, double) _yRange(Iterable<double> ys) {
    final allYs = ys.toList();
    if (targetValue != null) allYs.add(targetValue!);
    double minY = allYs.reduce(min);
    double maxY = allYs.reduce(max);

    if (minY == maxY) {
      if (minY == 0) {
        maxY = 10;
      } else {
        minY -= 1;
        maxY += 1;
      }
    } else {
      final padding = (maxY - minY) * 0.12;
      minY -= padding;
      maxY += padding;
    }

    if (_isCount && minY < 0) minY = 0;
    if (_useBars) minY = 0;
    return (minY, maxY);
  }

  ExtraLinesData? _goalExtraLines(BuildContext context) {
    if (targetValue == null) return null;
    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: targetValue!,
          color: context.colors.orange.withValues(alpha: 0.85),
          strokeWidth: 1.5,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.colors.orange,
            ),
            labelResolver: (_) {
              final t = targetValue!;
              if (_isCount && t >= 1000) {
                return 'Goal ${(t / 1000).toStringAsFixed(1)}k';
              }
              if (_isCount) return 'Goal ${t.toStringAsFixed(0)}';
              return 'Goal ${t.toStringAsFixed(1)}';
            },
          ),
        ),
      ],
    );
  }

  Widget _bottomTitle(BuildContext context, double value, TitleMeta meta) {
    final int daysOffset = value.round();
    final maxX = _maxXValue;
    if (daysOffset < 0 || daysOffset > maxX) {
      return const SizedBox.shrink();
    }

    final date = startDate.add(Duration(days: daysOffset));
    String label;

    if (timeFormat == ChartTimeFormat.weekly) {
      label = DateFormat('E').format(date);
    } else if (timeFormat == ChartTimeFormat.monthly) {
      // ~weekly anchors — quieter than every 5 days.
      final lastDay = DateTime(date.year, date.month + 1, 0).day;
      final show = date.day == 1 ||
          date.day == 8 ||
          date.day == 15 ||
          date.day == 22 ||
          date.day == lastDay;
      if (!show) return const SizedBox.shrink();
      label = date.day.toString();
    } else {
      if (date.day != 1) return const SizedBox.shrink();
      label = DateFormat('MMM').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: context.colors.textLight,
        ),
      ),
    );
  }

  Widget _leftTitle(BuildContext context, double value, TitleMeta meta) {
    if (_isCount && value < 0) return const SizedBox.shrink();

    String label;
    if (_isCount) {
      if (value >= 1000) {
        final kVal = value / 1000;
        label = '${kVal.toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
      } else {
        label = value.toInt().toString();
      }
    } else {
      label = value.toStringAsFixed(1);
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: context.colors.textLight,
      ),
    );
  }

  FlTitlesData _titlesData(BuildContext context) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: timeFormat == ChartTimeFormat.weekly ? 1 : null,
          getTitlesWidget: (value, meta) => _bottomTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => _leftTitle(context, value, meta),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  String _tooltipText(DateTime date, double value) {
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final valStr = value.toStringAsFixed(_isCount ? 0 : 1);
    final unit = _unitSuffix();
    String extra = '';
    if (targetValue != null) {
      final diff = value - targetValue!;
      final sign = diff >= 0 ? '+' : '';
      extra =
          '\n$sign${diff.toStringAsFixed(_isCount ? 0 : 1)}$unit vs goal';
    }
    return '$dateStr\n$valStr$unit$extra';
  }

  /// Split into contiguous day segments so missing days show as gaps, not zeros.
  List<List<FlSpot>> _segmentSpots(List<FlSpot> sorted) {
    if (sorted.isEmpty) return const [];
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].x - sorted[i - 1].x;
      if (gap > 1.5) {
        segments.add(current);
        current = <FlSpot>[sorted[i]];
      } else {
        current.add(sorted[i]);
      }
    }
    segments.add(current);
    return segments;
  }

  Widget _buildBarChart(BuildContext context) {
    final sorted = data.toList()..sort((a, b) => a.date.compareTo(b.date));
    final byDay = {
      for (final d in sorted) d.date.difference(startDate).inDays: d.value,
    };
    final primary = context.colors.primary;
    final (minY, maxY) = _yRange(sorted.map((d) => d.value));
    final daySpan = _maxXValue.toInt();
    final barWidth = daySpan <= 7
        ? 14.0
        : daySpan <= 31
            ? 7.0
            : 4.0;

    // One group per calendar day so missing days stay as visual gaps.
    final groups = <BarChartGroupData>[
      for (int x = 0; x <= daySpan; x++)
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: byDay[x] ?? 0,
              width: barWidth,
              borderRadius: byDay.containsKey(x) 
                  ? const BorderRadius.vertical(top: Radius.circular(4))
                  : BorderRadius.zero,
              color: byDay.containsKey(x)
                  ? primary
                  : Colors.transparent,
              gradient: byDay.containsKey(x)
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        primary.withValues(alpha: 0.55),
                        primary,
                      ],
                    )
                  : null,
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        extraLinesData: _goalExtraLines(context),
        titlesData: _titlesData(context),
        borderData: FlBorderData(show: false),
        barGroups: groups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.textDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (!byDay.containsKey(group.x) || rod.toY <= 0) {
                return null;
              }
              final date = startDate.add(Duration(days: group.x));
              return BarTooltipItem(
                _tooltipText(date, rod.toY),
                TextStyle(
                  color: context.colors.card,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final sorted = data.toList()..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted
        .map(
          (d) => FlSpot(
            d.date.difference(startDate).inDays.toDouble(),
            d.value,
          ),
        )
        .toList();

    final segments = _segmentSpots(spots);
    final (minY, maxY) = _yRange(spots.map((s) => s.y));
    final maxXValue = _maxXValue;
    final showDots = spots.length <= 14;
    final useCurve = spots.length > 2;
    final primary = context.colors.primary;

    final lineBars = <LineChartBarData>[
      for (final segment in segments)
        LineChartBarData(
          spots: segment,
          isCurved: useCurve && segment.length > 2,
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          color: primary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: showDots || segment.length == 1,
            getDotPainter: (spot, percent, bar, index) {
              return FlDotCirclePainter(
                radius: 3.5,
                color: primary,
                strokeWidth: 1.5,
                strokeColor: context.colors.card,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: segment.length > 1,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primary.withValues(alpha: 0.22),
                primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXValue,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        extraLinesData: _goalExtraLines(context),
        titlesData: _titlesData(context),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response != null &&
                response.lineBarSpots != null &&
                response.lineBarSpots!.isNotEmpty) {
              if (event is FlLongPressEnd && onPointLongPress != null) {
                final spot = response.lineBarSpots!.first;
                final date = startDate.add(Duration(days: spot.x.toInt()));
                onPointLongPress!(date, spot.y);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => context.colors.textDark,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = startDate.add(Duration(days: spot.x.toInt()));
                return LineTooltipItem(
                  _tooltipText(date, spot.y),
                  TextStyle(
                    color: context.colors.card,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}

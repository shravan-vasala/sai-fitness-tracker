import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';
import '../../models/daily_log.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import 'widgets/shared_chart_card.dart';
import 'widgets/metric_overview_card.dart';
import '../home/weight_entry_dialog.dart';
import '../home/steps_entry_dialog.dart';
import '../home/sleep_entry_dialog.dart';
import '../../models/daily_meal_log.dart';

enum MetricType { weight, steps, sleep, bmi, bodyFat, calories, protein, screenTime }
enum TimeRange { weekly, monthly, sixMonths }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.initialMetric});
  
  final MetricType? initialMetric;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late MetricType _selectedMetric;
  TimeRange _selectedRange = TimeRange.monthly;
  late DateTime _currentReferenceDate;

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.initialMetric ?? MetricType.weight;
    _currentReferenceDate = DateTime.now();
  }

  DateTime get _startDate {
    final d = _currentReferenceDate;
    switch (_selectedRange) {
      case TimeRange.weekly:
        final daysToSubtract = d.weekday - DateTime.monday;
        return DateTime(d.year, d.month, d.day - daysToSubtract);
      case TimeRange.monthly:
        return DateTime(d.year, d.month, 1);
      case TimeRange.sixMonths:
        return DateTime(d.year, d.month - 5, 1);
    }
  }

  DateTime get _endDate {
    final d = _currentReferenceDate;
    switch (_selectedRange) {
      case TimeRange.weekly:
        return _startDate.add(Duration(days: 6));
      case TimeRange.monthly:
        return DateTime(d.year, d.month + 1, 0);
      case TimeRange.sixMonths:
        return DateTime(d.year, d.month + 1, 0);
    }
  }

  void _shiftDate(int direction) {
    setState(() {
      if (_selectedRange == TimeRange.weekly) {
        _currentReferenceDate = _currentReferenceDate.add(Duration(days: 7 * direction));
      } else if (_selectedRange == TimeRange.monthly) {
        _currentReferenceDate = DateTime(_currentReferenceDate.year, _currentReferenceDate.month + direction, 1);
      } else {
        _currentReferenceDate = DateTime(_currentReferenceDate.year, _currentReferenceDate.month + (6 * direction), 1);
      }
    });
  }

  String get _headerText {
    if (_selectedRange == TimeRange.weekly) {
      return '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    } else if (_selectedRange == TimeRange.monthly) {
      return DateFormat('MMM yyyy').format(_startDate);
    } else {
      return '${DateFormat('MMM yyyy').format(_startDate)} - ${DateFormat('MMM yyyy').format(_endDate)}';
    }
  }

  Future<void> _handlePointLongPress(DateTime date, double value) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Entry?'),
        content: Text('Are you sure you want to delete the ${_metricLabel(_selectedMetric)} entry for ${DateFormat('MMM dd').format(date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(dailyLogRepoProvider);
      final log = repo.getLog(dateStr);
      if (log != null) {
        final newLog = DailyLog(
          date: log.date,
          weight: _selectedMetric == MetricType.weight ? null : log.weight,
          steps: _selectedMetric == MetricType.steps ? null : log.steps,
          stepsSource: _selectedMetric == MetricType.steps ? null : log.stepsSource,
          sleepHours: _selectedMetric == MetricType.sleep ? null : log.sleepHours,
          bodyFat: _selectedMetric == MetricType.bodyFat ? null : log.bodyFat,
          workoutCompleted: log.workoutCompleted,
          workoutDayId: log.workoutDayId,
        );
        await repo.saveLog(newLog);
        ref.invalidate(dailyLogsRangeProvider);
        ref.invalidate(dailyLogProvider);
      }
    }
  }

  void _openManualEntry() {
    if (_selectedMetric == MetricType.weight || _selectedMetric == MetricType.bodyFat || _selectedMetric == MetricType.bmi) {
      showAppBottomSheet(context: context, builder: (_) => WeightEntryDialog());
    } else if (_selectedMetric == MetricType.steps) {
      showAppBottomSheet(context: context, builder: (_) => StepsEntryDialog());
    } else if (_selectedMetric == MetricType.sleep) {
      showAppBottomSheet(context: context, builder: (_) => SleepEntryDialog());
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    final logs = ref.watch(dailyLogsRangeProvider((startStr, endStr)));
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text('My Progress'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (_selectedMetric != MetricType.bmi &&
              _selectedMetric != MetricType.calories &&
              _selectedMetric != MetricType.protein)
            IconButton(
              icon: Icon(Icons.add_rounded),
              onPressed: _openManualEntry,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Time range segmented control
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kScreenPadding),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.all(4),
              child: Row(
                children: TimeRange.values.map((range) {
                  final isSelected = _selectedRange == range;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedRange = range;
                        _currentReferenceDate = DateTime.now();
                      }),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? context.colors.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: context.colors.primary.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _rangeLabel(range),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? context.colors.primary
                                  : context.colors.textMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 12),

          // Date range navigator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded,
                      color: context.colors.primary),
                  onPressed: () => _shiftDate(-1),
                ),
                Text(
                  _headerText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textDark,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded,
                      color: context.colors.primary),
                  onPressed: () => _shiftDate(1),
                ),
              ],
            ),
          ),

          Center(
            child: ActionChip(
              backgroundColor: context.colors.lavenderCard,
              side: BorderSide.none,
              label: Text(
                'This Week Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
              onPressed: () {
                context.go('/progress/weekly-summary');
              },
            ),
          ),
          SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  _selectedMetric == MetricType.calories
                      ? _buildCaloriesChart(startStr, endStr, profile)
                      : _selectedMetric == MetricType.protein
                        ? _buildProteinChart(startStr, endStr, profile)
                        : _buildChart(logs, profile.useKg, profile),
                ],
              ),
            ),
          ),

          // Metric tab bar (icons below chart)
          Container(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 12),
            decoration: BoxDecoration(
              color: context.colors.card,
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: MetricType.values.where((m) => m != MetricType.screenTime || profile.screenTimeEnabled).map((metric) {
                final isSelected = _selectedMetric == metric;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedMetric = metric),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _metricIcon(metric),
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.textLight,
                          size: 22,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _metricLabel(metric),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.textLight,
                          ),
                        ),
                        SizedBox(height: 4),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 18,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.colors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      ),
    );
  }



  List<ChartDataPoint> _dailyMetricSeries(
    List<DailyLog> logs,
    MetricType metric,
    UserProfile profile,
  ) {
    final logsByDate = {for (var l in logs) l.date: l};
    final daysDiff = _endDate.difference(_startDate).inDays;
    final data = <ChartDataPoint>[];
    final useKg = profile.useKg;

    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      if (log == null) continue;

      double? val;
      switch (metric) {
        case MetricType.weight:
          val = log.weight != null
              ? (useKg ? log.weight! : log.weight! * 2.20462)
              : null;
          break;
        case MetricType.steps:
          val = log.steps?.toDouble();
          break;
        case MetricType.sleep:
          val = log.sleepHours;
          break;
        case MetricType.screenTime:
          if (log.screenTimeMinutes != null) {
            val = log.screenTimeMinutes! / 60.0; // convert to hours
          }
          break;
        case MetricType.bodyFat:
          val = log.bodyFat;
          break;
        case MetricType.bmi:
          if (log.weight != null) {
            final h = profile.heightInMeters;
            val = log.weight! / (h * h);
          }
          break;
        case MetricType.calories:
        case MetricType.protein:
          val = null;
          break;
      }
      if (val != null) data.add(ChartDataPoint(d, val));
    }
    return data;
  }

  List<ChartDataPoint> _mealSeries(
    List<DailyMealLog> mealLogs, {
    required bool calories,
  }) {
    final logsByDate = {for (var l in mealLogs) l.date: l};
    final daysDiff = _endDate.difference(_startDate).inDays;
    final data = <ChartDataPoint>[];

    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      if (log == null) continue;
      if (calories) {
        if (log.totalCalories > 0) {
          data.add(ChartDataPoint(d, log.totalCalories.toDouble()));
        }
      } else if (log.totalProtein > 0) {
        data.add(ChartDataPoint(d, log.totalProtein));
      }
    }
    return data;
  }

  String _formatOverviewValue(double value, MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight:
        return '${value.toStringAsFixed(1)} ${useKg ? 'kg' : 'lb'}';
      case MetricType.steps:
        return value.toInt().toString();
      case MetricType.sleep:
        return '${value.toStringAsFixed(1)}h';
      case MetricType.screenTime:
        return '${value.toStringAsFixed(1)}h';
      case MetricType.bodyFat:
        return '${value.toStringAsFixed(1)}%';
      case MetricType.calories:
        return '${value.toInt()} kcal';
      case MetricType.protein:
        return '${value.toStringAsFixed(0)}g';
      case MetricType.bmi:
        return value.toStringAsFixed(1);
    }
  }

  /// Primary overview value = period average (coach-friendly).
  String _overviewAvgText(
    List<ChartDataPoint> data,
    MetricType metric,
    bool useKg,
  ) {
    if (data.isEmpty) return '—';
    final avg = data.map((d) => d.value).reduce((a, b) => a + b) / data.length;
    return _formatOverviewValue(avg, metric, useKg);
  }

  /// Subtitle: "avg this period" + delta vs first point when useful.
  String? _overviewSubtitle(
    List<ChartDataPoint> data,
    MetricType metric,
    bool useKg,
  ) {
    if (data.isEmpty) return null;

    final parts = <String>['avg this period'];
    final isTrendMetric = metric == MetricType.weight ||
        metric == MetricType.bodyFat ||
        metric == MetricType.bmi ||
        metric == MetricType.sleep;

    if (isTrendMetric && data.length >= 2) {
      final delta = data.last.value - data.first.value;
      final abs = delta.abs();
      final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
      switch (metric) {
        case MetricType.weight:
          parts.add(
            '$sign${abs.toStringAsFixed(1)} ${useKg ? 'kg' : 'lb'} vs start',
          );
          break;
        case MetricType.sleep:
        case MetricType.screenTime:
          parts.add('$sign${abs.toStringAsFixed(1)}h vs start');
          break;
        case MetricType.bodyFat:
          parts.add('$sign${abs.toStringAsFixed(1)}% vs start');
          break;
        case MetricType.bmi:
          parts.add('$sign${abs.toStringAsFixed(1)} vs start');
          break;
        default:
          break;
      }
    } else if (data.length == 1) {
      parts.add('1 entry');
    } else {
      parts.add('${data.length} days');
    }
    return parts.join(' · ');
  }

  Widget _buildChart(List<DailyLog> logs, bool useKg, dynamic profile) {
    final List<ChartDataPoint> data = [];
    final daysDiff = _endDate.difference(_startDate).inDays;
    final logsByDate = {for (var l in logs) l.date: l};
    
    int daysWithData = 0;

    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      
      if (log != null) {
        double? val;
        switch (_selectedMetric) {
          case MetricType.weight:
            val = log.weight != null ? (useKg ? log.weight! : log.weight! * 2.20462) : null;
            break;
          case MetricType.steps:
            val = log.steps?.toDouble();
            break;
          case MetricType.sleep:
            val = log.sleepHours;
            break;
          case MetricType.screenTime:
            if (log.screenTimeMinutes != null) {
              val = log.screenTimeMinutes! / 60.0;
            }
            break;
          case MetricType.bmi:
            if (log.weight != null) {
              final h = profile.heightInMeters;
              val = log.weight! / (h * h);
            }
            break;
          case MetricType.bodyFat:
            val = log.bodyFat;
            break;
          case MetricType.calories:
          case MetricType.protein:
            val = null;
            break;
        }
        
        if (val != null) {
          // Treat 0 steps as "not logged" so the line doesn't crash to zero.
          if (_selectedMetric == MetricType.steps && val <= 0) continue;
          data.add(ChartDataPoint(d, val));
          daysWithData++;
        }
      }
    }

    List<String> labels = [];
    List<String> values = [];
    
    if (daysWithData > 0) {
      final validData = data;
      
      if (_selectedMetric == MetricType.steps) {
        final validSteps = validData.where((d) => d.value > 0).map((d) => d.value).toList();
        if (validSteps.isNotEmpty) {
          final total = validSteps.reduce((a, b) => a + b);
          final avg = total ~/ validSteps.length;
          final maxVal = validSteps.reduce((a, b) => a > b ? a : b);
          labels = ['AVERAGE\n(${validSteps.length} days)', 'TOTAL', 'MAX'];
          values = [avg.toString(), total.toInt().toString(), maxVal.toInt().toString()];
        }
      } else {
        final vals = validData.map((d) => d.value).toList();
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        final maxVal = vals.reduce((a, b) => a > b ? a : b);
        final minVal = vals.reduce((a, b) => a < b ? a : b);
        
        if (_selectedMetric == MetricType.weight) {
          final unit = useKg ? 'kg' : 'lb';
          labels = ['AVERAGE\n(${vals.length} days)', 'MAX', 'MIN'];
          values = ['${avg.toStringAsFixed(1)} $unit', '${maxVal.toStringAsFixed(1)} $unit', '${minVal.toStringAsFixed(1)} $unit'];
        } else if (_selectedMetric == MetricType.sleep || _selectedMetric == MetricType.screenTime) {
          labels = ['AVERAGE\n(${vals.length} days)', 'MAX', 'MIN'];
          values = ['${avg.toStringAsFixed(1)}h', '${maxVal.toStringAsFixed(1)}h', '${minVal.toStringAsFixed(1)}h'];
        } else if (_selectedMetric == MetricType.bmi) {
          labels = ['AVERAGE\n(${vals.length} days)', 'MAX', 'MIN'];
          values = [avg.toStringAsFixed(1), maxVal.toStringAsFixed(1), minVal.toStringAsFixed(1)];
        } else if (_selectedMetric == MetricType.bodyFat) {
          labels = ['AVERAGE\n(${vals.length} days)', 'MAX', 'MIN'];
          values = ['${avg.toStringAsFixed(1)}%', '${maxVal.toStringAsFixed(1)}%', '${minVal.toStringAsFixed(1)}%'];
        }
      }
    }

    ChartTimeFormat format;
    switch (_selectedRange) {
      case TimeRange.weekly: format = ChartTimeFormat.weekly; break;
      case TimeRange.monthly: format = ChartTimeFormat.monthly; break;
      case TimeRange.sixMonths: format = ChartTimeFormat.sixMonths; break;
    }

    // Empty state logic: if no true valid data exists, we hide the chart
    final isEmpty = daysWithData == 0;
    String emptyMessage = 'No ${_metricLabel(_selectedMetric).toLowerCase()} entries yet.';
    if (_selectedMetric == MetricType.bmi) {
      emptyMessage = 'Log your weight to see BMI.';
    }

    return SharedChartCard(
      title: _metricTitle(_selectedMetric),
      data: isEmpty ? [] : data,
      startDate: _startDate,
      endDate: _endDate,
      isSteps: _selectedMetric == MetricType.steps,
      showKgLbToggle: _selectedMetric == MetricType.weight,
      useKg: useKg,
      onToggleUnit: () => ref.read(profileProvider.notifier).toggleUnit(),
      statLabels: isEmpty ? [] : labels,
      statValues: isEmpty ? [] : values,
      timeFormat: format,
      emptyMessage: emptyMessage,
      targetValue: _selectedMetric == MetricType.weight && profile.targetWeight != null
          ? (useKg
              ? profile.targetWeight as double
              : (profile.targetWeight as double) * 2.20462)
          : null,
      onPointLongPress: _handlePointLongPress,
    );
  }

  Widget _buildCaloriesChart(String startStr, String endStr, dynamic profile) {
    final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
    final List<ChartDataPoint> data = [];
    final logsByDate = {for (var l in mealLogs) l.date: l};
    final daysDiff = _endDate.difference(_startDate).inDays;
    
    final validCalories = <int>[];

    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      
      if (log != null && log.totalCalories > 0) {
        data.add(ChartDataPoint(d, log.totalCalories.toDouble()));
        validCalories.add(log.totalCalories);
      }
      // Skip zero / missing days — chart gaps instead of fake dips.
    }
    
    List<String> labels = [];
    List<String> values = [];
    
    if (validCalories.isNotEmpty) {
      final sum = validCalories.reduce((a, b) => a + b);
      final avg = sum ~/ validCalories.length;
      final maxVal = validCalories.reduce((a, b) => a > b ? a : b);
      final minVal = validCalories.reduce((a, b) => a < b ? a : b);
      labels = ['AVERAGE\n(${validCalories.length} days)', 'MAX', 'MIN'];
      values = [avg.toString(), maxVal.toString(), minVal.toString()];
    }

    ChartTimeFormat format;
    switch (_selectedRange) {
      case TimeRange.weekly: format = ChartTimeFormat.weekly; break;
      case TimeRange.monthly: format = ChartTimeFormat.monthly; break;
      case TimeRange.sixMonths: format = ChartTimeFormat.sixMonths; break;
    }

    final isEmpty = validCalories.isEmpty;

    return SharedChartCard(
      title: 'Calories',
      data: isEmpty ? [] : data,
      startDate: _startDate,
      endDate: _endDate,
      isSteps: false,
      isCalories: true,
      showKgLbToggle: false,
      useKg: true,
      onToggleUnit: () {},
      statLabels: isEmpty ? [] : labels,
      statValues: isEmpty ? [] : values,
      timeFormat: format,
      emptyMessage: 'No calories logged yet.',
      targetValue: profile.targetCalories.toDouble(),
      onPointLongPress: null,
    );
  }

  Widget _buildProteinChart(String startStr, String endStr, UserProfile profile) {
    final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
    final daysDiff = _endDate.difference(_startDate).inDays;
    final logsByDate = {for (var l in mealLogs) l.date: l};
    
    final data = <ChartDataPoint>[];
    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      if (log != null && log.totalProtein > 0) {
        data.add(ChartDataPoint(d, log.totalProtein));
      }
    }

    List<String> labels = [];
    List<String> values = [];
    final validPoints = data.map((d) => d.value).toList();
    if (validPoints.isNotEmpty) {
      final avg = validPoints.reduce((a, b) => a + b) / validPoints.length;
      final maxVal = validPoints.reduce((a, b) => a > b ? a : b);
      labels = ['AVERAGE\n(${validPoints.length} days)', 'MAX'];
      values = ['${avg.toStringAsFixed(0)}g', '${maxVal.toStringAsFixed(0)}g'];
    }

    ChartTimeFormat format;
    switch (_selectedRange) {
      case TimeRange.weekly: format = ChartTimeFormat.weekly; break;
      case TimeRange.monthly: format = ChartTimeFormat.monthly; break;
      case TimeRange.sixMonths: format = ChartTimeFormat.sixMonths; break;
    }

    final isEmpty = validPoints.isEmpty;

    return SharedChartCard(
      title: 'Protein (g)',
      data: isEmpty ? [] : data,
      startDate: _startDate,
      endDate: _endDate,
      isSteps: false,
      isCalories: false,
      isProtein: true,
      showKgLbToggle: false,
      useKg: true,
      onToggleUnit: () {},
      statLabels: isEmpty ? [] : labels,
      statValues: isEmpty ? [] : values,
      timeFormat: format,
      emptyMessage: 'No protein logged yet.',
      targetValue: profile.targetProteinG.toDouble(),
      onPointLongPress: null,
    );
  }

  String _rangeLabel(TimeRange range) {
    switch (range) {
      case TimeRange.weekly: return 'Weekly';
      case TimeRange.monthly: return 'Monthly';
      case TimeRange.sixMonths: return '6 Months';
    }
  }

  String _metricTitle(MetricType metric) {
    switch (metric) {
      case MetricType.weight: return 'Body Weight';
      case MetricType.steps: return 'Steps';
      case MetricType.sleep: return 'Sleep';
      case MetricType.bmi: return 'BMI';
      case MetricType.bodyFat: return 'Body Fat';
      case MetricType.calories: return 'Calories';
      case MetricType.protein: return 'Protein';
      case MetricType.screenTime: return 'Screen Time';
    }
  }

  String _metricLabel(MetricType metric) {
    switch (metric) {
      case MetricType.weight: return 'Weight';
      case MetricType.steps: return 'Steps';
      case MetricType.sleep: return 'Sleep';
      case MetricType.bmi: return 'BMI';
      case MetricType.bodyFat: return 'Body Fat';
      case MetricType.calories: return 'Calories';
      case MetricType.protein: return 'Protein';
      case MetricType.screenTime: return 'Screen Time';
    }
  }

  IconData _metricIcon(MetricType metric) {
    switch (metric) {
      case MetricType.weight: return Icons.monitor_weight_rounded;
      case MetricType.steps: return Icons.directions_walk_rounded;
      case MetricType.sleep: return Icons.bedtime_rounded;
      case MetricType.bmi: return Icons.speed_rounded;
      case MetricType.bodyFat: return Icons.water_drop_rounded;
      case MetricType.calories: return Icons.restaurant_rounded;
      case MetricType.protein: return Icons.egg_rounded;
      case MetricType.screenTime: return Icons.smartphone_rounded;
    }
  }
}

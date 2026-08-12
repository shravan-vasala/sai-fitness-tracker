import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class SleepEntryDialog extends ConsumerStatefulWidget {
  const SleepEntryDialog({super.key});

  @override
  ConsumerState<SleepEntryDialog> createState() => _SleepEntryDialogState();
}

class _SleepEntryDialogState extends ConsumerState<SleepEntryDialog> {
  final _controller = TextEditingController();
  TimeOfDay? _bedtime;
  TimeOfDay? _waketime;
  bool _hasExistingEntry = false;

  @override
  void initState() {
    super.initState();
    final log = ref.read(dailyLogProvider);
    if (log.sleepHours != null) {
      _controller.text = log.sleepHours!.toStringAsFixed(1);
      _hasExistingEntry = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDurationFromTimes() {
    if (_bedtime == null || _waketime == null) return;
    
    // Compute duration
    double bedHours = _bedtime!.hour + _bedtime!.minute / 60.0;
    double wakeHours = _waketime!.hour + _waketime!.minute / 60.0;
    
    double duration = wakeHours - bedHours;
    if (duration < 0) {
      duration += 24.0;
    }
    
    _controller.text = duration.toStringAsFixed(1);
  }

  Future<void> _pickTime(bool isBedtime) async {
    final initialTime = isBedtime
        ? (_bedtime ?? TimeOfDay(hour: 22, minute: 0))
        : (_waketime ?? TimeOfDay(hour: 6, minute: 0));
    final parentTheme = Theme.of(context);

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(
          data: parentTheme.copyWith(
            colorScheme: parentTheme.colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: context.colors.onPrimary,
              onSurface: context.colors.textDark,
            ),
          ),
          child: child,
        );
      },
    );

    if (time != null) {
      setState(() {
        if (isBedtime) {
          _bedtime = time;
        } else {
          _waketime = time;
        }
      });
      _updateDurationFromTimes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isFuture = selectedDate.isAfter(today);
    final dateFormatted = DateFormat('EEE, d MMM').format(selectedDate);
    
    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log Sleep',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textDark,
                ),
              ),
              if (_hasExistingEntry)
                TextButton(
                  onPressed: () {
                    ref.read(dailyLogProvider.notifier).clearSleep();
                    
                    final habits = ref.read(habitsProvider);
                    final sleepHabit = habits.where((h) => h.name.toLowerCase().contains('sleep')).firstOrNull;
                    if (sleepHabit != null) {
                      ref.read(habitCompletionsProvider.notifier).setOverride(sleepHabit.id, 'none');
                    }
                    
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.pinkIcon,
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, 0),
                  ),
                  child: Text('Clear entry'),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Enter your sleep for $dateFormatted',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textMedium,
            ),
          ),
          SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            enabled: !isFuture,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              hintText: '0.0',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.textLight,
              ),
              suffixText: 'hrs',
              suffixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Or calculate from times:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textMedium,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimePickerCard(
                  title: 'Bedtime',
                  time: _bedtime,
                  onTap: isFuture ? null : () => _pickTime(true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TimePickerCard(
                  title: 'Wake up',
                  time: _waketime,
                  onTap: isFuture ? null : () => _pickTime(false),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          PrimaryButton(
            label: isFuture ? 'Cannot log for future date' : 'Save Sleep',
            onPressed: isFuture
                ? null
                : () {
                    final sleepHours = double.tryParse(_controller.text);
                    if (sleepHours != null &&
                        sleepHours >= 0 &&
                        sleepHours <= 16) {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(dailyLogProvider.notifier)
                          .updateSleep(sleepHours);
                          
                      final habits = ref.read(habitsProvider);
                      final sleepHabit = habits.where((h) => h.name.toLowerCase().contains('sleep')).firstOrNull;
                      if (sleepHabit != null && sleepHours >= sleepHabit.target) {
                        ref.read(habitCompletionsProvider.notifier).setOverride(sleepHabit.id, 'done');
                      }
                      
                      Navigator.of(context).pop();
                    } else if (sleepHours != null && sleepHours > 16) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a value between 0 and 16 hours',
                          ),
                        ),
                      );
                    }
                  },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({
    required this.title,
    required this.time,
    required this.onTap,
  });

  final String title;
  final TimeOfDay? time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
            SizedBox(height: 4),
            Text(
              time != null ? time!.format(context) : '--:--',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: time != null ? context.colors.textDark : context.colors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

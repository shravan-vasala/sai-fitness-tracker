import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class WaterEntryDialog extends ConsumerStatefulWidget {
  const WaterEntryDialog({super.key});

  @override
  ConsumerState<WaterEntryDialog> createState() => _WaterEntryDialogState();
}

class _WaterEntryDialogState extends ConsumerState<WaterEntryDialog> {
  final _controller = TextEditingController();
  bool _hasExistingEntry = false;
  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    final log = ref.read(dailyLogProvider);
    if (log.waterMl != null && log.waterMl! > 0) {
      _currentAmount = log.waterMl!;
      _controller.text = _currentAmount.toString();
      _hasExistingEntry = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addAmount(int amount) {
    setState(() {
      final currentTextAmount = int.tryParse(_controller.text) ?? 0;
      _currentAmount = currentTextAmount + amount;
      _controller.text = _currentAmount.toString();
    });
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Water Intake',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.lavenderCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dateFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          if (isFuture)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: context.colors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You cannot log water for future dates.',
                      style: TextStyle(color: context.colors.textDark, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Total (ml)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                    onChanged: (val) {
                      _currentAmount = int.tryParse(val) ?? 0;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.colors.card,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixText: 'ml',
                      suffixStyle: TextStyle(
                        fontSize: 16,
                        color: context.colors.textMedium,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.colors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _addAmount(250),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('+ 250ml', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _addAmount(500),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('+ 500ml', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              children: [
                if (_hasExistingEntry) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(dailyLogProvider.notifier).clearWater();
                        
                        final habits = ref.read(habitsProvider);
                        final waterHabit = habits.where((h) => h.name.toLowerCase().contains('water')).firstOrNull;
                        if (waterHabit != null) {
                          ref.read(habitCompletionsProvider.notifier).setOverride(waterHabit.id, 'none');
                        }
                        
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.red,
                        side: BorderSide(color: context.colors.red.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Clear', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Save Intake',
                    onPressed: () async {
                      final amount = int.tryParse(_controller.text) ?? 0;
                      if (amount > 0) {
                        await ref.read(dailyLogProvider.notifier).updateWater(amount);
                        
                        final habits = ref.read(habitsProvider);
                        final waterHabit = habits.where((h) => h.name.toLowerCase().contains('water')).firstOrNull;
                        if (waterHabit != null) {
                          double targetInMl = waterHabit.target.toDouble();
                          if (waterHabit.unit.toLowerCase() == 'l' || waterHabit.unit.toLowerCase() == 'liters') {
                            targetInMl *= 1000;
                          }
                          if (amount >= targetInMl) {
                            ref.read(habitCompletionsProvider.notifier).setOverride(waterHabit.id, 'done');
                          } else {
                            ref.read(habitCompletionsProvider.notifier).setOverride(waterHabit.id, 'none');
                          }
                        }
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

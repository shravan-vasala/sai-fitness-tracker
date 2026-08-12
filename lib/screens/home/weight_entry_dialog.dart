import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class WeightEntryDialog extends ConsumerStatefulWidget {
  const WeightEntryDialog({super.key});

  @override
  ConsumerState<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends ConsumerState<WeightEntryDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final log = ref.read(dailyLogProvider);
    if (log.weight != null) {
      _controller.text = log.weight!.toStringAsFixed(1);
      return;
    }

    final dateStr = ref.read(dateStringProvider);
    final end = DateTime.parse(dateStr).subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 90));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final logs =
        ref.read(dailyLogRepoProvider).getLogsInRange(fmt(start), fmt(end));
    for (int i = logs.length - 1; i >= 0; i--) {
      final w = logs[i].weight;
      if (w != null) {
        _controller.text = w.toStringAsFixed(1);
        break;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Log Body Weight',
      subtitle: 'Enter your weight for today',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              hintText: '0.0',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.textLight,
              ),
              suffixText: 'kg',
              suffixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
          SizedBox(height: 24),
          PrimaryButton(
            label: 'Save Weight',
            onPressed: () {
              final weight = double.tryParse(_controller.text);
              if (weight != null && weight > 0) {
                HapticFeedback.mediumImpact();
                ref.read(dailyLogProvider.notifier).updateWeight(weight);
                Navigator.of(context).pop();
              }
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

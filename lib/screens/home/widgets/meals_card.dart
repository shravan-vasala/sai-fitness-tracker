import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../models/meal_plan.dart';
import '../../../utils/meal_plan_complete.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/surface_card.dart';
import 'photo_calorie_scanner_sheet.dart';

class MealsCard extends ConsumerWidget {
  const MealsCard({super.key});

  void _openLogSheet(
    BuildContext context, {
    required String slotId,
    required String slotName,
    required bool describe,
  }) {
    HapticFeedback.selectionClick();
    showAppBottomSheet(
      context: context,
      builder: (_) => PhotoCalorieScannerSheet(
        slotId: slotId,
        slotDisplayName: slotName,
        isManualEntry: describe,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLog = ref.watch(dailyMealLogProvider);
    final profile = ref.watch(profileProvider);
    final mealPlan = ref.watch(mealPlanProvider);
    final planName = mealPlan?.planName ?? 'Daily Meal Plan';

    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isFuture = selectedDate.isAfter(today);
    final isToday = selectedDate.isAtSameMomentAs(today);

    final defaultIds = profile.customMealSlots
        .where((s) => s['isDefault'] == true)
        .map((s) => s['id'] as String)
        .toSet();
    final loggedIds = dailyLog.customSlots.keys.toSet();

    int totalMeals = defaultIds.length;
    if (isFuture || isToday) {
      final recurringIds =
          profile.customMealSlots.map((s) => s['id'] as String).toSet();
      totalMeals = recurringIds.union(loggedIds).length;
    } else {
      final customLoggedCount = loggedIds.difference(defaultIds).length;
      totalMeals = defaultIds.length + customLoggedCount;
    }

    final slots = <({String id, String name, String emoji})>[];
    for (final s in profile.customMealSlots) {
      slots.add((
        id: s['id'] as String,
        name: s['name'] as String,
        emoji: s['emoji'] as String,
      ));
    }

    final completedMeals = dailyLog.loggedSlotsCount;
    final completedCal = dailyLog.totalCalories;
    final totalCal = profile.targetCalories;
    final progress = (completedCal / totalCal).clamp(0.0, 1.0);
    final isOverTarget = completedCal > totalCal;

    String nextLabel = 'Open plan';
    for (final s in slots) {
      final log = dailyLog.customSlots[s.id];
      if (!MealPlanComplete.isSlotLogged(log)) {
        nextLabel = 'Next: ${s.name}';
        break;
      }
    }

    return Semantics(
      label:
          'Meals Card. $completedMeals of $totalMeals meals logged. $completedCal of $totalCal calories consumed.',
      child: SurfaceCard(
        margin: EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.go('/home/meals');
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Meals",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          planName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textLight,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.colors.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverTarget ? context.colors.orange : context.colors.green,
                ),
                minHeight: 6,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '$completedMeals/$totalMeals meals  ·  $completedCal/$totalCal kcal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMedium,
                  ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _MacroPill(
                  label: 'P',
                  value: '${dailyLog.totalProtein.toStringAsFixed(0)}g',
                  color: context.colors.green,
                ),
                SizedBox(width: 6),
                _MacroPill(
                  label: 'C',
                  value: '${dailyLog.totalCarbs.toStringAsFixed(0)}g',
                  color: context.colors.orange,
                ),
                SizedBox(width: 6),
                _MacroPill(
                  label: 'F',
                  value: '${dailyLog.totalFat.toStringAsFixed(0)}g',
                  color: context.colors.primary,
                ),
              ],
            ),

            if (!isFuture) ...[
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.go('/home/meals');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    nextLabel,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

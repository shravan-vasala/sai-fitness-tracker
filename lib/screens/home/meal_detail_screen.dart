import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import '../../models/daily_meal_log.dart';
import '../../models/meal_plan.dart';
import '../../utils/meal_plan_complete.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/surface_card.dart';
import 'widgets/photo_calorie_scanner_sheet.dart';
import 'widgets/add_meal_slot_dialog.dart';
import 'widgets/ai_meal_suggestion_card.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key});

  void _openAddSlotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddMealSlotDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLog = ref.watch(dailyMealLogProvider);
    final profile = ref.watch(profileProvider);
    final mealPlan = ref.watch(mealPlanProvider);
    final planName = mealPlan?.planName ?? 'Daily Meal Plan';

    final targetCalories = profile.targetCalories;
    final isOverTarget = dailyLog.totalCalories > targetCalories;
    final progressRatio =
        (dailyLog.totalCalories / (targetCalories > 0 ? targetCalories : 1))
            .clamp(0.0, 1.0);

    final List<({String id, String name, String emoji})> slotsToDisplay = [];
    final recurringIds = <String>{};

    for (final s in profile.customMealSlots) {
      final id = s['id'] as String;
      recurringIds.add(id);
      slotsToDisplay.add((
        id: id,
        name: s['name'] as String,
        emoji: s['emoji'] as String,
      ));
    }

    for (final entry in dailyLog.customSlots.entries) {
      if (!recurringIds.contains(entry.key)) {
        final log = entry.value;
        slotsToDisplay.add((
          id: entry.key,
          name: log.name ?? 'Meal',
          emoji: log.emoji ?? '🍽️',
        ));
      }
    }

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Today's meals"),
            Text(
              planName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          kShellScrollBottomPadding + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: slotsToDisplay.length + 4,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _CalorieHeader(
                  eaten: dailyLog.totalCalories,
                  target: targetCalories,
                  progress: progressRatio,
                  isOverTarget: isOverTarget,
                  protein: dailyLog.totalProtein,
                  carbs: dailyLog.totalCarbs,
                  fat: dailyLog.totalFat,
                  proteinTarget: profile.targetProteinG.toDouble(),
                  carbsTarget: profile.targetCarbsG.toDouble(),
                  fatTarget: profile.targetFatG.toDouble(),
                ),
                const SizedBox(height: 24),
              ],
            );
          } else if (index <= slotsToDisplay.length) {
            final s = slotsToDisplay[index - 1];
            return _MealSlotCard(
              slotId: s.id,
              slotName: s.name,
              slotEmoji: s.emoji,
              slotLog: dailyLog.customSlots[s.id],
              plannedMeal: MealPlanComplete.plannedForSlot(mealPlan, s.id),
            );
          } else if (index == slotsToDisplay.length + 1) {
            final unloggedSlots = slotsToDisplay.where((s) {
              final slotLog = dailyLog.customSlots[s.id];
              return slotLog == null || slotLog.items.isEmpty;
            }).toList();
            final mealsLeft = unloggedSlots.length;
            final mealName = unloggedSlots.isNotEmpty ? unloggedSlots.first.name : null;

            return AIMealSuggestionCard(
              remainingCalories: targetCalories - dailyLog.totalCalories,
              remainingProtein: profile.targetProteinG.toDouble() - dailyLog.totalProtein,
              remainingCarbs: profile.targetCarbsG.toDouble() - dailyLog.totalCarbs,
              remainingFat: profile.targetFatG.toDouble() - dailyLog.totalFat,
              mealName: mealName,
              mealsLeft: mealsLeft,
            );
          } else if (index == slotsToDisplay.length + 2) {
            return const SizedBox(height: 16);
          } else {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openAddSlotDialog(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add another meal',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  backgroundColor: context.colors.primary.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: context.colors.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _CalorieHeader extends StatelessWidget {
  const _CalorieHeader({
    required this.eaten,
    required this.target,
    required this.progress,
    required this.isOverTarget,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
  });

  final int eaten;
  final int target;
  final double progress;
  final bool isOverTarget;
  final double protein;
  final double carbs;
  final double fat;
  final double proteinTarget;
  final double carbsTarget;
  final double fatTarget;

  @override
  Widget build(BuildContext context) {
    final accent = isOverTarget ? context.colors.orange : context.colors.primary;

    return SurfaceCard(
      elevation: SurfaceCardElevation.nested,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$eaten',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'of $target kcal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMedium,
                  ),
                ),
                if (isOverTarget) ...[
                  SizedBox(height: 2),
                  Text(
                    '+${eaten - target} over',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.orange,
                    ),
                  ),
                ],
                SizedBox(height: 14),
                _MacroBar(
                  label: 'Protein',
                  current: protein,
                  target: proteinTarget,
                  color: context.colors.green,
                ),
                SizedBox(height: 10),
                _MacroBar(
                  label: 'Carbs',
                  current: carbs,
                  target: carbsTarget,
                  color: context.colors.orange,
                ),
                SizedBox(height: 10),
                _MacroBar(
                  label: 'Fat',
                  current: fat,
                  target: fatTarget,
                  color: context.colors.indigo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  final String label;
  final double current;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
            ),
            Text(
              '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _MealSlotCard extends ConsumerStatefulWidget {
  const _MealSlotCard({
    required this.slotId,
    required this.slotName,
    required this.slotEmoji,
    this.slotLog,
    this.plannedMeal,
  });

  final String slotId;
  final String slotName;
  final String slotEmoji;
  final MealSlotLog? slotLog;
  final Meal? plannedMeal;

  @override
  ConsumerState<_MealSlotCard> createState() => _MealSlotCardState();
}

class _MealSlotCardState extends ConsumerState<_MealSlotCard> {

  bool get _hasLog => MealPlanComplete.isSlotLogged(widget.slotLog);

  bool get _isPlannedComplete =>
      MealPlanComplete.isPlannedComplete(widget.slotLog);

  @override
  Widget build(BuildContext context) {
    final planned = widget.plannedMeal;
    final slotLog = widget.slotLog;

    return SurfaceCard(
      margin: EdgeInsets.only(bottom: 16),
      elevation: SurfaceCardElevation.nested,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(widget.slotEmoji, style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.slotName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textDark,
                        ),
                      ),
                      if (!_hasLog && planned != null) ...[
                        if (planned.calories > 0) ...[
                          SizedBox(height: 2),
                          Text(
                            'Target ~${planned.calories} kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textLight,
                            ),
                          ),
                        ],


                      ],
                    ],
                  ),
                ),
                if (_hasLog)
                  Text(
                    '${slotLog!.totalCalories} kcal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                  ),
                if (_hasLog) ...[
                  SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.colors.green,
                    size: 20,
                  ),
                ] else if (slotLog != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: context.colors.textMedium,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      ref
                          .read(dailyMealLogProvider.notifier)
                          .clearMealSlot(widget.slotId);
                    },
                  ),
                ],
              ],
            ),
          ),

          // Logged non-planned content
          if (_hasLog && !_isPlannedComplete) ...[
            Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (slotLog!.photoPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                slotLog.photoPath!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(slotLog.photoPath!),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                      ),
                    if (slotLog.photoPath != null) SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: slotLog.items.map((item) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.lavender,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.name} · ${item.portion}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: context.colors.textLight,
                      size: 14,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: CompactButton(
                      label: 'Add serving',
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: () => _openScanner(context, false, append: true),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CompactButton(
                      label: 'Replace meal',
                      icon: Icons.refresh_rounded,
                      onPressed: () => _openScanner(context, false),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Photo & describe first — home cooking primary path
          if (!_hasLog)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CompactButton(
                          label: 'Take photo',
                          icon: Icons.camera_alt_outlined,
                          filled: true,
                          onPressed: () => _openScanner(context, false),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: CompactButton(
                          label: 'Describe',
                          icon: Icons.notes_rounded,
                          onPressed: () => _openScanner(context, true),
                        ),
                      ),
                    ],
                  ),
                  if (planned != null)
                    TextButton(
                      onPressed: () => _toggleCompletedAsPlanned(planned),
                      child: Text(
                        'Or mark completed as planned',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else if (_isPlannedComplete)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: CompactButton(
                      label: 'Replace with photo',
                      icon: Icons.camera_alt_outlined,
                      onPressed: () => _openScanner(context, false),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CompactButton(
                      label: 'Describe',
                      icon: Icons.notes_rounded,
                      onPressed: () => _openScanner(context, true),
                    ),
                  ),
                ],
              ),
            ),

          if (planned != null && _hasLog && !_isPlannedComplete)
            Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 12, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleCompletedAsPlanned(planned),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank_rounded,
                        color: context.colors.textMedium,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Switch to completed as planned',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (planned != null && _isPlannedComplete)
            Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 12, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleCompletedAsPlanned(planned),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_rounded,
                        color: context.colors.green,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Completed as planned',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(height: 8),

          if (planned != null && planned.suggestions.isNotEmpty)
            _buildSuggestions(context, planned),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, Meal planned) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: context.colors.primary),
              SizedBox(width: 6),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...planned.suggestions.map((suggestion) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _toggleCompletedAsPlanned(Meal planned) async {
    final notifier = ref.read(dailyMealLogProvider.notifier);
    if (_isPlannedComplete) {
      HapticFeedback.selectionClick();
      await notifier.clearMealSlot(widget.slotId);
      return;
    }

    if (_hasLog) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Overwrite Meal?'),
          content: Text('This will remove your scanned photos and macros and replace them with the planned meal. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Overwrite', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final profile = ref.read(profileProvider);
    final log = MealPlanComplete.buildSlotLog(
      planned: planned,
      slotName: widget.slotName,
      slotEmoji: widget.slotEmoji,
      profile: profile,
    );

    HapticFeedback.mediumImpact();
    await notifier.saveMealSlot(widget.slotId, log);
  }

  void _openScanner(BuildContext context, bool isManualEntry, {bool append = false}) {
    showAppBottomSheet(
      context: context,
      builder: (_) => PhotoCalorieScannerSheet(
        slotId: widget.slotId,
        slotDisplayName: widget.slotName,
        isManualEntry: isManualEntry,
        appendToLog: append ? widget.slotLog : null,
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/habit.dart';
import '../../utils/habit_icons.dart';

class ManageHabitsScreen extends ConsumerStatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  ConsumerState<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends ConsumerState<ManageHabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Manage Habits',
          style: TextStyle(color: context.colors.textDark),
        ),
        backgroundColor: context.colors.scaffoldBg,
        foregroundColor: context.colors.textDark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.colors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_rounded, color: context.colors.primary),
            tooltip: 'Remind me daily',
            onPressed: () => context.go('/profile/reminders'),
          ),
        ],
      ),
      body: habits.isEmpty
          ? Center(
              child: Text(
                'No habits found. Add one!',
                style: TextStyle(color: context.colors.textMedium),
              ),
            )
          : ReorderableListView.builder(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 100),
              itemCount: habits.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final list = List<Habit>.from(habits);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                ref.read(habitRepoProvider).reorderHabits(list).then((_) {
                  ref.invalidate(habitsProvider);
                });
              },
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _HabitListTile(
                  key: ValueKey(habit.id),
                  habit: habit,
                );
              },
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showEditorDialog(context, ref, null),
          backgroundColor: context.colors.primary,
          icon: Icon(Icons.add, color: context.colors.onPrimary),
          label: Text(
            'Add Habit',
            style: TextStyle(color: context.colors.onPrimary),
          ),
        ),
      ),
    );
  }

  void _showEditorDialog(BuildContext context, WidgetRef ref, Habit? habit) {
    showDialog(
      context: context,
      builder: (ctx) => _HabitEditorDialog(habit: habit),
    );
  }
}

class _HabitListTile extends ConsumerWidget {
  final Habit habit;
  const _HabitListTile({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: key,
      color: context.colors.card,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(
          HabitIcons.resolve(habit.icon),
          color: context.colors.primary,
          size: 28,
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.colors.textDark,
          ),
        ),
        subtitle: Text(
          _getTypeDescription(habit),
          style: TextStyle(color: context.colors.textMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, color: context.colors.primary),
              tooltip: 'Edit habit',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => _HabitEditorDialog(habit: habit),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: context.colors.red),
              tooltip: 'Delete habit',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Delete Habit?'),
                    content: Text(
                      'Are you sure you want to delete this habit? History will be kept for past days, but it won\'t appear anymore.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(habitRepoProvider).deleteHabit(habit.id).then((_) {
                            if (!context.mounted) return;
                            ref.invalidate(habitsProvider);
                            Navigator.pop(ctx);
                          });
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(color: context.colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(width: 8),
            Icon(Icons.drag_handle_rounded, color: context.colors.textMedium),
          ],
        ),
      ),
    );
  }

  String _getTypeDescription(Habit h) {
    switch (h.type) {
      case HabitType.checkbox:
        if (h.unit.isNotEmpty && h.target > 0) {
          final t = h.target == h.target.roundToDouble()
              ? h.target.toInt().toString()
              : h.target.toString();
          return 'Tap once · Goal: $t ${h.unit}';
        }
        return 'Tap once to complete';
      case HabitType.counter:
        return 'Counter (Target: ${h.target} ${h.unit})';
      case HabitType.autoSteps:
        return 'Auto from Steps (Target: ${h.target})';
      case HabitType.autoSleep:
        return 'From sleep log (Target: ${h.target} hrs)';
      case HabitType.autoFromScreenTime:
        return 'From screen time (Target: ${h.target} mins)';
    }
  }
}

class _HabitEditorDialog extends ConsumerStatefulWidget {
  final Habit? habit;
  const _HabitEditorDialog({this.habit});

  @override
  ConsumerState<_HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends ConsumerState<_HabitEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _stepCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  String _selectedIcon = 'check';
  HabitType _type = HabitType.checkbox;
  bool _isWaterHabit = false;

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      final h = widget.habit!;
      _isWaterHabit = h.id == 'water';
      _nameCtrl.text = h.name;
      _selectedIcon = HabitIcons.normalize(h.icon);
      _type = h.type;
      _targetCtrl.text = h.target.toString();
      _stepCtrl.text = h.step.toString();
      _unitCtrl.text = h.unit;
    } else {
      _targetCtrl.text = '1';
      _stepCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _stepCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _syncWaterNameFromGoal() {
    if (!_isWaterHabit) return;
    final target = double.tryParse(_targetCtrl.text) ?? 3.0;
    final unit = _unitCtrl.text.trim().isEmpty ? 'L' : _unitCtrl.text.trim();
    final targetLabel = target == target.roundToDouble()
        ? target.toInt().toString()
        : target.toString();
    _nameCtrl.text = 'Drink $targetLabel $unit of water';
  }

  void _submit() {
    var name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    var target = double.tryParse(_targetCtrl.text) ?? 1.0;
    final step = double.tryParse(_stepCtrl.text) ?? 1.0;
    var unit = _unitCtrl.text.trim();

    // Water: always checkbox with customizable daily goal
    var type = _type;
    if (_isWaterHabit) {
      type = HabitType.checkbox;
      if (unit.isEmpty) unit = 'L';
      if (target <= 0) target = 3.0;
      final targetLabel = target == target.roundToDouble()
          ? target.toInt().toString()
          : target.toString();
      name = 'Drink $targetLabel $unit of water';
    }

    final isNew = widget.habit == null;
    final id = isNew
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : widget.habit!.id;

    final updated = Habit(
      id: id,
      name: name,
      icon: HabitIcons.normalize(_selectedIcon),
      type: type,
      target: target,
      step: step,
      unit: unit,
      createdAt: isNew ? DateTime.now() : widget.habit!.createdAt,
      order: isNew ? ref.read(habitsProvider).length : widget.habit!.order,
    );

    ref.read(habitRepoProvider).saveHabit(updated).then((_) {
      if (!mounted) return;
      ref.invalidate(habitsProvider);
      Navigator.pop(context);
    });
  }

  bool get _showGoalFields =>
      _isWaterHabit || _type != HabitType.checkbox;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.habit == null ? 'Add Habit' : 'Edit Habit',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: context.colors.textDark,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isWaterHabit)
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: context.colors.textDark),
                decoration: InputDecoration(
                  labelText: 'Habit Name',
                  hintText: 'e.g. Meditate 10 min',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? context.colors.scaffoldBg
                      : context.colors.lavender,
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  hintStyle: TextStyle(color: context.colors.textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else ...[
              Text(
                'Daily water goal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap once on Home to mark it done. Change how much you aim for below.',
                style: TextStyle(fontSize: 13, color: context.colors.textLight),
              ),
            ],
            SizedBox(height: 16),
            Text(
              'Icon',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitIcons.options.map((opt) {
                final isSelected = opt.id == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = opt.id),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.primary.withValues(alpha: 0.2)
                          : context.colors.scaffoldBg,
                      border: Border.all(
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      opt.icon,
                      size: 22,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textMedium,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (!_isWaterHabit) ...[
              SizedBox(height: 20),
              DropdownButtonFormField<HabitType>(
                initialValue: _type,
                dropdownColor: context.colors.card,
                style: TextStyle(
                  color: context.colors.textDark,
                  fontSize: 14,
                ),
                iconEnabledColor: context.colors.textMedium,
                decoration: InputDecoration(
                  labelText: 'Type',
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? context.colors.scaffoldBg
                      : context.colors.lavender,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: HabitType.checkbox,
                    child: Text(
                      'Checkbox (Tap once)',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.counter,
                    child: Text(
                      'Counter (+ / −)',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoSteps,
                    child: Text(
                      'Auto from Steps',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoSleep,
                    child: Text(
                      'Auto from Sleep',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoFromScreenTime,
                    child: Text(
                      'Auto from Screen Time',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _type = val);
                },
              ),
            ],
            if (_showGoalFields) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetCtrl,
                      style: TextStyle(color: context.colors.textDark),
                      decoration: InputDecoration(
                        labelText: _isWaterHabit ? 'Amount' : 'Target',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        if (_isWaterHabit) {
                          setState(_syncWaterNameFromGoal);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitCtrl,
                      style: TextStyle(color: context.colors.textDark),
                      decoration: InputDecoration(
                        labelText: _isWaterHabit ? 'Unit' : 'Unit (e.g. L)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        if (_isWaterHabit) {
                          setState(_syncWaterNameFromGoal);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_isWaterHabit) ...[
                SizedBox(height: 12),
                Text(
                  _nameCtrl.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ],
            if (_type == HabitType.counter && !_isWaterHabit) ...[
              SizedBox(height: 16),
              TextField(
                controller: _stepCtrl,
                style: TextStyle(color: context.colors.textDark),
                decoration: InputDecoration(
                  labelText: 'Increment Step (e.g. 0.25)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: context.colors.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('Save'),
        ),
      ],
    );
  }
}

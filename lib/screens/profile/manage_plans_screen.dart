import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';

class ManagePlansScreen extends ConsumerWidget {
  const ManagePlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final workoutRepo = ref.watch(workoutRepoProvider);
    final mealRepo = ref.watch(mealRepoProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.colors.scaffoldBg,
        appBar: AppBar(
          title: Text('Manage Plans'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            labelColor: context.colors.primary,
            unselectedLabelColor: context.colors.textMedium,
            indicatorColor: context.colors.primary,
            isScrollable: true,
            tabs: [
              Tab(text: 'Workout Plans'),
              Tab(text: 'Meal Plans'),
              Tab(text: 'Meal Slots'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Active Plans Selection
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: context.colors.card,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active Workout', style: TextStyle(fontSize: 12, color: context.colors.textMedium, fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: profile.activeWorkoutPlan,
                          isExpanded: true,
                          hint: Text('Select Plan', style: TextStyle(fontSize: 14)),
                          items: workoutRepo.getPlanKeys().map((k) => DropdownMenuItem(value: k, child: Text(k, style: TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(activeWorkoutPlan: val),
                                  );
                            }
                          },
                        ),
                        if (profile.planStartDate != null)
                          TextButton(
                            onPressed: () {
                              ref.read(profileProvider.notifier).updateProfile(
                                    profile.copyWith(
                                      clearPlanStart: true,
                                      currentPhaseWeek: 1,
                                    ),
                                  );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 30),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text('Reset phase progress', style: TextStyle(fontSize: 11, color: context.colors.red)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active Meals', style: TextStyle(fontSize: 12, color: context.colors.textMedium, fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: profile.activeMealPlan,
                          isExpanded: true,
                          hint: Text('Select Plan', style: TextStyle(fontSize: 14)),
                          items: mealRepo.getPlanKeys().map((k) => DropdownMenuItem(value: k, child: Text(k, style: TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(activeMealPlan: val),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PlanEditor(
                    type: 'workout',
                    getKeys: () => workoutRepo.getPlanKeys(),
                    getRawJson: (key) => workoutRepo.getRawPlanJson(key),
                    saveJson: (key, json) => workoutRepo.savePlanJson(key, json),
                  ),
                  _PlanEditor(
                    type: 'meal',
                    getKeys: () => mealRepo.getPlanKeys(),
                    getRawJson: (key) => mealRepo.getRawPlanJson(key),
                    saveJson: (key, json) => mealRepo.savePlanJson(key, json),
                  ),
                  _MealSlotsEditor(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSlotsEditor extends ConsumerStatefulWidget {
  const _MealSlotsEditor();
  @override
  ConsumerState<_MealSlotsEditor> createState() => _MealSlotsEditorState();
}

class _MealSlotsEditorState extends ConsumerState<_MealSlotsEditor> {
  void _deleteSlot(Map<String, dynamic> slot) {
    final profile = ref.read(profileProvider);
    final updatedSlots = profile.customMealSlots.where((s) => s['id'] != slot['id']).toList();
    ref.read(profileProvider.notifier).updateProfile(
          profile.copyWith(customMealSlots: updatedSlots),
        );
  }

  void _editSlot(Map<String, dynamic> slot, int index) {
    final nameCtrl = TextEditingController(text: slot['name'] as String);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Meal Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final profile = ref.read(profileProvider);
              final updatedSlots = List<Map<String, dynamic>>.from(profile.customMealSlots);
              updatedSlots[index] = {
                ...updatedSlots[index],
                'name': nameCtrl.text.trim(),
                'emoji': '',
              };
              ref.read(profileProvider.notifier).updateProfile(
                    profile.copyWith(customMealSlots: updatedSlots),
                  );
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final slots = profile.customMealSlots;

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isDefault = slot['isDefault'] == true;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(slot['emoji'] as String, style: TextStyle(fontSize: 24)),
            title: Text(slot['name'] as String, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isDefault ? 'Default Slot' : 'Custom Recurring Slot'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_rounded, color: context.colors.primary),
                  onPressed: () => _editSlot(slot, index),
                ),
                if (!isDefault)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: context.colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete Slot?'),
                          content: Text('Removing this recurring slot means it will no longer appear on future days. Previously logged food will still be kept.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                _deleteSlot(slot);
                                Navigator.pop(ctx);
                              },
                              child: Text('Delete', style: TextStyle(color: context.colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    required this.type,
    required this.getKeys,
    required this.getRawJson,
    required this.saveJson,
  });

  final String type;
  final List<String> Function() getKeys;
  final String? Function(String) getRawJson;
  final Future<void> Function(String, String) saveJson;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  String? _selectedKey;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final keys = widget.getKeys();
    if (keys.isNotEmpty) {
      _selectedKey = keys.first;
      _loadJson();
    }
  }

  void _loadJson() {
    if (_selectedKey != null) {
      final json = widget.getRawJson(_selectedKey!);
      _controller.text = json ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.getKeys();

    if (keys.isEmpty) {
      return Center(child: Text('No plans found'));
    }

    return Column(
      children: [
        // Plan selector
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.colors.lavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedKey,
                    isExpanded: true,
                    underline: SizedBox(),
                    items: keys.map((k) {
                      return DropdownMenuItem(
                        value: k,
                        child: Text(k, style: TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedKey = v;
                        _loadJson();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(Icons.save_rounded, size: 18),
                label: Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        // JSON editor
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: context.colors.textDark,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'Paste JSON here...',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_selectedKey == null) return;
    try {
      await widget.saveJson(_selectedKey!, _controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan saved successfully'),
            backgroundColor: context.colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('FormatException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation Error: $errorMsg'),
            backgroundColor: context.colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

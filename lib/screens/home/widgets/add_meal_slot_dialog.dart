import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../models/daily_meal_log.dart';

class AddMealSlotDialog extends ConsumerStatefulWidget {
  const AddMealSlotDialog({super.key});

  @override
  ConsumerState<AddMealSlotDialog> createState() => _AddMealSlotDialogState();
}

class _AddMealSlotDialogState extends ConsumerState<AddMealSlotDialog> {
  final _nameCtrl = TextEditingController();
  String _selectedEmoji = '🍴';
  bool _addToEveryDay = false;

  final _emojis = ['🍴', '🥤', '🍌', '🥜', '🍚', '🫖', '🍪', '🥩', '🥑', '🥪', '🥣', '🥗'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final id = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    if (_addToEveryDay) {
      final profile = ref.read(profileProvider);
      final updatedSlots = List<Map<String, dynamic>>.from(profile.customMealSlots)
        ..add({
          'id': id,
          'name': name,
          'emoji': _selectedEmoji,
          'isDefault': false,
        });
      ref.read(profileProvider.notifier).updateProfile(profile.copyWith(customMealSlots: updatedSlots));
    }
    
    // Create an empty log entry for today so it immediately appears (and persists name/emoji)
    final slotLog = MealSlotLog(
      name: name,
      emoji: _selectedEmoji,
      items: [],
      totalCalories: 0,
      totalProtein: 0,
      totalCarbs: 0,
      totalFat: 0,
    );
    
    ref.read(dailyMealLogProvider.notifier).saveMealSlot(id, slotLog);

    Navigator.pop(context);
    
    // Optionally open the scanner immediately for the new slot
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: true,
    //   backgroundColor: Colors.transparent,
    //   builder: (_) => PhotoCalorieScannerSheet(slotId: id, slotName: name, isManualEntry: false),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.scaffoldBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Add Meal Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Meal Name',
                hintText: 'e.g. Post-workout shake',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),
            Text('Choose an emoji', style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textMedium)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? context.colors.primary.withValues(alpha: 0.2) : context.colors.card,
                      border: Border.all(color: isSelected ? context.colors.primary : context.colors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Switch(
                  value: _addToEveryDay,
                  onChanged: (val) => setState(() => _addToEveryDay = val),
                  activeTrackColor: context.colors.primary.withValues(alpha: 0.5),
                  activeThumbColor: context.colors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Add to every day?', style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textDark)),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4.0),
              child: Text(
                'If enabled, this slot will appear every day. Otherwise, just today.',
                style: TextStyle(fontSize: 12, color: context.colors.textMedium),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: context.colors.textLight)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Add Slot'),
        ),
      ],
    );
  }
}

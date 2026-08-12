import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/primary_button.dart';
import '../../../services/gemini_food_service.dart';
import '../../../providers/app_providers.dart';

class AIMealSuggestionCard extends ConsumerStatefulWidget {
  final int remainingCalories;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFat;
  final String? mealName;
  final int mealsLeft;

  const AIMealSuggestionCard({
    super.key,
    required this.remainingCalories,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    this.mealName,
    this.mealsLeft = 1,
  });

  @override
  ConsumerState<AIMealSuggestionCard> createState() => _AIMealSuggestionCardState();
}

class _AIMealSuggestionCardState extends ConsumerState<AIMealSuggestionCard> {
  bool _isLoading = false;
  Map<String, dynamic>? _suggestion;
  String? _error;

  Future<void> _fetchSuggestion() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(geminiFoodServiceProvider);
      
      final dateStr = ref.read(dateStringProvider);
      final mealRepo = ref.read(mealRepoProvider);
      final todayLogs = mealRepo.getLogsInRange(dateStr, dateStr);
      final previousMeals = todayLogs
          .expand((l) => l.customSlots.values)
          .expand((slot) => slot.items)
          .map((i) => i.name)
          .where((name) => name.isNotEmpty)
          .toList();

      final result = await service.suggestMeal(
        remainingCalories: widget.remainingCalories,
        remainingProtein: widget.remainingProtein,
        remainingCarbs: widget.remainingCarbs,
        remainingFat: widget.remainingFat,
        mealName: widget.mealName,
        mealsLeft: widget.mealsLeft,
        previousMeals: previousMeals,
      );
      setState(() {
        _suggestion = result;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remainingCalories <= 0) {
      return SurfaceCard(
        elevation: SurfaceCardElevation.nested,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded, color: context.colors.green, size: 40),
              const SizedBox(height: 12),
              Text(
                'Calorie Goal Reached!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You hit your target for today. Great job!',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SurfaceCard(
      elevation: SurfaceCardElevation.nested,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: context.colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Smart Meal Suggestion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_suggestion != null) ...[
              Text(
                _suggestion!['dish_name'] ?? 'Unknown Dish',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Portion: ${_suggestion!['portion']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _suggestion!['reason'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroItem(label: 'Kcal', value: '${_suggestion!['calories']}'),
                  _MacroItem(label: 'Protein', value: '${_suggestion!['protein_g']}g'),
                  _MacroItem(label: 'Carbs', value: '${_suggestion!['carbs_g']}g'),
                  _MacroItem(label: 'Fat', value: '${_suggestion!['fat_g']}g'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _fetchSuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    side: BorderSide(color: context.colors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Suggest Something Else'),
                ),
              ),
            ] else ...[
              Text(
                'Need ideas for your next meal? I can suggest a dish that perfectly fits your remaining macros (${widget.remainingCalories} kcal left).',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: context.colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: _fetchSuggestion,
                label: 'Suggest a Meal',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  final String label;
  final String value;

  const _MacroItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.colors.textDark,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.colors.textMedium,
          ),
        ),
      ],
    );
  }
}

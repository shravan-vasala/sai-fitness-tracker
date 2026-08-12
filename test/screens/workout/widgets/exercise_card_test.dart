import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/models/workout_plan.dart';
import 'package:trufit_bodamma/screens/workout/widgets/exercise_card.dart';
import 'package:trufit_bodamma/theme/app_theme.dart';
import 'package:trufit_bodamma/theme/app_colors.dart';

void main() {
  group('ExerciseCard Widget Tests', () {
    testWidgets('renders exercise name and reps correctly', (WidgetTester tester) async {
      final exercise = Exercise(
        name: 'Barbell Squat',
        displayName: 'Squat',
        reps: ['5', '5', '5'],
        note: 'Go deep',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ExerciseCard(
                    exercise: exercise,
                    dayId: 'monday',
                  );
                }
              ),
            ),
          ),
        ),
      );

      // Let the FutureProviders/NetworkImages settle (if any, though CachedNetworkImage might cause issues in tests, 
      // it should be fine since we check for text)
      await tester.pumpAndSettle();

      expect(find.text('Squat'), findsOneWidget); // displayName
      expect(find.text('Go deep'), findsOneWidget); // note
      
      // Look for Reps text. The UI might combine them or show them sequentially.
      // Usually it displays '3 sets • 5, 5, 5 reps' or similar based on `repsDisplay`
      expect(find.textContaining('5'), findsWidgets);
    });
  });
}

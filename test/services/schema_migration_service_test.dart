import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/schema_migration_service.dart';

void main() {
  test('SchemaMigrationService migrates v1 profile to v2 with default macros', () {
    final Map<String, dynamic> v1Manifest = {
      'schemaVersion': 1,
      'boxes': {
        'user_profile': {
          'profile': jsonEncode({
            'name': 'Old User',
            'targetCalories': 2000,
          })
        }
      }
    };

    final boxes = v1Manifest['boxes'] as Map<String, dynamic>;
    final version = v1Manifest['schemaVersion'] as int;
    
    final migratedBoxes = SchemaMigrationService.runMigrationsForRestore(boxes, version);
    
    // Test verification
    final profileJsonStr = migratedBoxes['user_profile']['profile'] as String;
    final profileJson = jsonDecode(profileJsonStr) as Map<String, dynamic>;
    
    expect(profileJson['name'], 'Old User');
    expect(profileJson['targetCalories'], 2000);
    
    // v2 fields added
    expect(profileJson['targetProteinG'], 120);
    expect(profileJson['targetCarbsG'], 150);
    expect(profileJson['targetFatG'], 50);
  });
}

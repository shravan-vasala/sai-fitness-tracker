import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:trufit_bodamma/services/backup_encryption_service.dart';
import 'package:trufit_bodamma/services/schema_migration_service.dart';

class BackupRestoreResult {
  final bool success;
  final int failedPhotosCount;
  BackupRestoreResult({required this.success, this.failedPhotosCount = 0});
}

class BackupVerificationResult {
  final bool isValid;
  final int totalEntries;
  final int photoCount;
  final String? errorMessage;
  final bool isEncrypted;

  final int schemaVersion;
  final String appVersion;
  final String createdAt;

  BackupVerificationResult({
    required this.isValid,
    required this.totalEntries,
    required this.photoCount,
    this.errorMessage,
    this.isEncrypted = false,
    this.schemaVersion = 0,
    this.appVersion = 'Unknown',
    this.createdAt = 'Unknown',
  });
}

class BackupService {
  /// The list of known Hive boxes to back up.
  static const List<String> _boxesToBackup = [
    'health_connect_meta',
    'workout_plans',
    'workout_sessions',
    'meal_plans',
    'user_profile',
    'scanned_photo_meals',
    'media_metadata',
    'daily_meal_logs',
    'meal_completions',
    'habit_config',
    'habit_completions',
    'exercise_logs',
    'exercise_prs',
    'daily_logs',
    'body_stats',
    'coach_notes',
  ];

  /// Creates a ZIP archive containing a manifest of all Hive data and the physical photos.
  Future<String?> createBackup({String? password}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final manifestData = <String, dynamic>{
        'schemaVersion': SchemaMigrationService.currentSchemaVersion,
        'appVersion': packageInfo.version,
        'createdAt': DateTime.now().toIso8601String(),
        'boxes': <String, dynamic>{},
      };
      
      final prefs = await SharedPreferences.getInstance();
      final reminderConfigJson = prefs.getString('reminder_config');
      if (reminderConfigJson != null) {
        manifestData['reminder_config'] = reminderConfigJson;
      }
      
      final manifestBoxes = <String, Map<String, dynamic>>{};

      // 1. Read all Hive boxes into the manifest
      for (final boxName in _boxesToBackup) {
        final box = await _openHiveBox(boxName);
        final boxData = <String, dynamic>{};
        for (final key in box.keys) {
          String valStr = box.get(key)?.toString() ?? '';
          
          // Ensure geminiApiKey is never backed up
          if (boxName == 'user_profile' && key == 'profile') {
            try {
              final Map<String, dynamic> map = jsonDecode(valStr);
              if (map.containsKey('geminiApiKey')) {
                map.remove('geminiApiKey');
                valStr = jsonEncode(map);
              }
            } catch (_) {}
          }
          
          boxData[key.toString()] = valStr;
        }
        manifestBoxes[boxName] = boxData;
      }
      
      manifestData['boxes'] = manifestBoxes;

      // 2. Identify all photos to backup
      final photosToBackup = <String>{};
      if (manifestBoxes.containsKey('media_metadata')) {
        final mediaBox = manifestBoxes['media_metadata']!;
        for (final key in mediaBox.keys) {
          if (key.startsWith('photos_')) {
            final String jsonStr = mediaBox[key];
            try {
              final List<dynamic> paths = jsonDecode(jsonStr);
              for (final path in paths) {
                photosToBackup.add(path.toString());
              }
            } catch (_) {}
          }
        }
      }

      // Add profile photo if present
      if (manifestBoxes.containsKey('user_profile')) {
        final profileBox = manifestBoxes['user_profile']!;
        final profileJsonStr = profileBox['profile'];
        if (profileJsonStr != null) {
          try {
            final Map<String, dynamic> profileMap = jsonDecode(profileJsonStr);
            if (profileMap['photoPath'] != null) {
              photosToBackup.add(profileMap['photoPath'] as String);
            }
          } catch (_) {}
        }
      }

      // Meal slot photos (AI / camera logs) live in daily_meal_logs JSON
      if (manifestBoxes.containsKey('daily_meal_logs')) {
        _collectMealLogPhotoPaths(
          manifestBoxes['daily_meal_logs']!,
          photosToBackup,
        );
      }

      // 3. Create the Archive
      final archive = Archive();
      
      final bool isEncrypted = password != null && password.isNotEmpty;
      final securityBytes = utf8.encode(jsonEncode({'encrypted': isEncrypted}));
      archive.addFile(ArchiveFile('security.json', securityBytes.length, securityBytes));
      
      // Add manifest.json
      Uint8List manifestBytes = utf8.encode(jsonEncode(manifestData));
      if (isEncrypted) {
        manifestBytes = BackupEncryptionService.encryptBytes(manifestBytes, password);
        archive.addFile(ArchiveFile('manifest.enc', manifestBytes.length, manifestBytes));
      } else {
        archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      }

      // Add photos
      for (final photoPath in photosToBackup) {
        final file = File(photoPath);
        if (await file.exists()) {
          final fileName = file.uri.pathSegments.last;
          Uint8List bytes = await file.readAsBytes();
          
          if (isEncrypted) {
            bytes = BackupEncryptionService.encryptBytes(bytes, password);
            archive.addFile(ArchiveFile('photos/$fileName.enc', bytes.length, bytes));
          } else {
            archive.addFile(ArchiveFile('photos/$fileName', bytes.length, bytes));
          }
        }
      }

      // 4. Save to a temporary zip file
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFile = File('${tempDir.path}/trufit_backup_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      return zipFile.path;
    } catch (e) {
      debugPrint('Backup error: $e');
      return null;
    }
  }

  /// Extracts the backup to a temporary directory and verifies its contents.
  Future<BackupVerificationResult> verifyBackup(String zipPath, {String? password}) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: 'File does not exist');
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      bool isEncrypted = false;
      final securityFile = archive.findFile('security.json');
      if (securityFile != null) {
        final securityContent = utf8.decode(securityFile.content as List<int>);
        final securityMap = jsonDecode(securityContent) as Map<String, dynamic>;
        isEncrypted = securityMap['encrypted'] == true;
      }

      if (isEncrypted && (password == null || password.isEmpty)) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Password required');
      }

      // Find manifest
      ArchiveFile? manifestFile = archive.findFile(isEncrypted ? 'manifest.enc' : 'manifest.json');
      if (manifestFile == null) {
        // Fallback for older backups
        manifestFile = archive.findFile('manifest.json');
        isEncrypted = false;
      }
      
      if (manifestFile == null) {
        return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: 'Missing manifest.json');
      }

      String manifestContent;
      if (isEncrypted) {
        try {
          final decrypted = BackupEncryptionService.decryptBytes(Uint8List.fromList(manifestFile.content as List<int>), password!);
          manifestContent = utf8.decode(decrypted);
        } catch (e) {
          return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, isEncrypted: true, errorMessage: 'Incorrect password or invalid backup file.');
        }
      } else {
        manifestContent = utf8.decode(manifestFile.content as List<int>);
      }
      
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      int schemaVersion = 0;
      String appVersion = 'Unknown';
      String createdAt = 'Unknown';
      Map<String, dynamic> boxes = manifest;

      if (manifest.containsKey('schemaVersion')) {
        schemaVersion = manifest['schemaVersion'] as int? ?? 1;
        appVersion = manifest['appVersion'] as String? ?? 'Unknown';
        createdAt = manifest['createdAt'] as String? ?? 'Unknown';
        boxes = manifest['boxes'] as Map<String, dynamic>? ?? {};
      }

      int entriesCount = 0;
      for (final box in boxes.values) {
        entriesCount += (box as Map).length;
      }

      // Count photos in archive
      int photosCount = archive.where((f) => f.name.startsWith('photos/') && f.isFile).length;

      return BackupVerificationResult(
        isValid: true,
        totalEntries: entriesCount,
        photoCount: photosCount,
        isEncrypted: isEncrypted,
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        createdAt: createdAt,
      );
    } catch (e) {
      return BackupVerificationResult(isValid: false, totalEntries: 0, photoCount: 0, errorMessage: e.toString());
    }
  }

  /// Restores a backup. WARNING: This will overwrite existing data.
  Future<BackupRestoreResult> restoreBackup(String zipPath, {String? password}) async {
    try {
      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      bool isEncrypted = false;
      final securityFile = archive.findFile('security.json');
      if (securityFile != null) {
        final securityContent = utf8.decode(securityFile.content as List<int>);
        final securityMap = jsonDecode(securityContent) as Map<String, dynamic>;
        isEncrypted = securityMap['encrypted'] == true;
      }

      if (isEncrypted && (password == null || password.isEmpty)) {
        throw Exception('Password required to restore this backup.');
      }

      ArchiveFile? manifestFile = archive.findFile(isEncrypted ? 'manifest.enc' : 'manifest.json');
      if (manifestFile == null) {
        manifestFile = archive.findFile('manifest.json');
        isEncrypted = false;
      }
      if (manifestFile == null) return BackupRestoreResult(success: false);

      String manifestContent;
      if (isEncrypted) {
        try {
          final decrypted = BackupEncryptionService.decryptBytes(Uint8List.fromList(manifestFile.content as List<int>), password!);
          manifestContent = utf8.decode(decrypted);
        } catch (e) {
          throw Exception('Incorrect password or invalid backup file.');
        }
      } else {
        manifestContent = utf8.decode(manifestFile.content as List<int>);
      }
      
      final manifestData = jsonDecode(manifestContent) as Map<String, dynamic>;

      Map<String, dynamic> boxes = manifestData;
      int manifestVersion = 1;
      if (manifestData.containsKey('schemaVersion')) {
        manifestVersion = manifestData['schemaVersion'] as int? ?? 1;
        boxes = manifestData['boxes'] as Map<String, dynamic>? ?? {};
      }

      if (manifestVersion > SchemaMigrationService.currentSchemaVersion) {
        throw FormatException(
            'Backup schema version ($manifestVersion) is newer than the app version (${SchemaMigrationService.currentSchemaVersion}). '
            'Please update the app to restore this backup.');
      }

      boxes = SchemaMigrationService.runMigrationsForRestore(boxes, manifestVersion);

      if (manifestData.containsKey('reminder_config')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reminder_config', manifestData['reminder_config'] as String);
      }

      // 0. Create pre-restore safety net
      final backupPath = await createBackup();
      if (backupPath != null) {
        final docDir = await getApplicationDocumentsDirectory();
        final safetyNetFile = File('${docDir.path}/pre_restore_safety_net.zip');
        if (await safetyNetFile.exists()) {
          await safetyNetFile.delete();
        }
        await File(backupPath).copy(safetyNetFile.path);
      }

      // 1. Wipe every known box first — older backups may omit boxes and would
      // otherwise leave stale local data mixed with restored data.
      final boxesToWipe = <String>{
        ..._boxesToBackup,
        ...boxes.keys.map((k) => k.toString()),
      };
      for (final boxName in boxesToWipe) {
        final box = await _openHiveBox(boxName);
        await box.clear();
      }

      // 2. Apply backup contents
      for (final boxName in boxes.keys) {
        final box = await _openHiveBox(boxName.toString());
        final Map<String, dynamic> boxData =
            Map<String, dynamic>.from(boxes[boxName] as Map);
        for (final entry in boxData.entries) {
          await box.put(entry.key, entry.value.toString());
        }
      }

      // 3. Restore photos
      int failedPhotosCount = 0;
      final docDir = await getApplicationDocumentsDirectory();
      final oldPathMap = <String, String>{};
      for (final file in archive) {
        if (file.isFile && file.name.startsWith('photos/')) {
          String fileName = file.name.split('/').last;
          Uint8List fileContent = Uint8List.fromList(file.content as List<int>);
          
          if (isEncrypted && fileName.endsWith('.enc')) {
            fileName = fileName.substring(0, fileName.length - 4);
            try {
              fileContent = BackupEncryptionService.decryptBytes(fileContent, password!);
            } catch (_) {
              failedPhotosCount++;
              continue;
            }
          }
          
          final newFilePath = '${docDir.path}/$fileName';
          final newFile = File(newFilePath);
          await newFile.writeAsBytes(fileContent);
          oldPathMap[fileName] = newFilePath;
        }
      }

      // Fix paths in media_metadata
      if (boxes.containsKey('media_metadata')) {
        final mediaBox = await _openHiveBox('media_metadata');
        final currentKeys = mediaBox.keys.toList();
        for (final key in currentKeys) {
          if (key.toString().startsWith('photos_')) {
            final jsonStr = mediaBox.get(key)?.toString();
            if (jsonStr != null) {
              final List<dynamic> oldPaths = jsonDecode(jsonStr);
              final List<String> newPaths = [];
              for (final oldPath in oldPaths) {
                final fileName = File(oldPath.toString()).uri.pathSegments.last;
                if (oldPathMap.containsKey(fileName)) {
                  newPaths.add(oldPathMap[fileName]!);
                  
                  // Also we need to fix the pose tag keys
                  final oldPoseKey = 'pose_$oldPath';
                  final poseVal = mediaBox.get(oldPoseKey);
                  if (poseVal != null) {
                    await mediaBox.put('pose_${oldPathMap[fileName]}', poseVal);
                    await mediaBox.delete(oldPoseKey);
                  }
                } else {
                  // Fallback: keep the old path if it wasn't backed up (edge case)
                  newPaths.add(oldPath.toString());
                }
              }
              await mediaBox.put(key, jsonEncode(newPaths));
            }
          }
        }
      }

      // Also fix paths in scanned_photo_meals
      if (boxes.containsKey('scanned_photo_meals')) {
        final mealBox = await _openHiveBox('scanned_photo_meals');
        final keys = mealBox.keys.toList();
        for (final key in keys) {
          final oldPath = key.toString();
          final fileName = File(oldPath).uri.pathSegments.last;
          if (oldPathMap.containsKey(fileName)) {
            final val = mealBox.get(oldPath);
            await mealBox.put(oldPathMap[fileName]!, val!);
            await mealBox.delete(oldPath);
          }
        }
      }

      // Fix profile photo path
      if (boxes.containsKey('user_profile')) {
        final profileBox = await _openHiveBox('user_profile');
        final profileJsonStr = profileBox.get('profile')?.toString();
        if (profileJsonStr != null) {
          try {
            final Map<String, dynamic> profileMap = jsonDecode(profileJsonStr);
            if (profileMap['photoPath'] != null) {
              final oldPath = profileMap['photoPath'] as String;
              final fileName = File(oldPath).uri.pathSegments.last;
              if (oldPathMap.containsKey(fileName)) {
                profileMap['photoPath'] = oldPathMap[fileName];
                await profileBox.put('profile', jsonEncode(profileMap));
              }
            }
          } catch (_) {}
        }
      }

      // Fix meal slot photo paths in daily_meal_logs
      if (boxes.containsKey('daily_meal_logs')) {
        final mealLogBox = await _openHiveBox('daily_meal_logs');
        final keys = mealLogBox.keys.toList();
        for (final key in keys) {
          final jsonStr = mealLogBox.get(key)?.toString();
          if (jsonStr == null) continue;
          try {
            final Map<String, dynamic> logMap = jsonDecode(jsonStr);
            if (_rewriteMealLogPhotoPaths(logMap, oldPathMap)) {
              await mealLogBox.put(key, jsonEncode(logMap));
            }
          } catch (_) {}
        }
      }

      return BackupRestoreResult(success: true, failedPhotosCount: failedPhotosCount);
    } on FormatException {
      rethrow;
    } catch (e) {
      debugPrint('Restore error: $e');
      return BackupRestoreResult(success: false);
    }
  }

  /// Creates a data-only backup and maintains the latest 4 in getExternalStorageDirectory.
  Future<void> autoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAutoStr = prefs.getString('last_auto_backup_date');
      final now = DateTime.now();
      
      if (lastAutoStr != null) {
        final lastAuto = DateTime.tryParse(lastAutoStr);
        if (lastAuto != null && now.difference(lastAuto).inDays < 7) {
          return;
        }
      }

      final manifest = <String, Map<String, dynamic>>{};
      for (final boxName in _boxesToBackup) {
        final box = await _openHiveBox(boxName);
        final boxData = <String, dynamic>{};
        for (final key in box.keys) {
          boxData[key.toString()] = box.get(key);
        }
        manifest[boxName] = boxData;
      }

      final archive = Archive();
      final manifestBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      
      final backupsDir = Directory('${extDir.path}/AutoBackups');
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }

      final timestamp = now.millisecondsSinceEpoch;
      final zipFile = File('${backupsDir.path}/trufit_auto_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      final files = backupsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.zip')).toList();
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      
      while (files.length > 4) {
        final oldest = files.removeAt(0);
        if (await oldest.exists()) await oldest.delete();
      }

      await prefs.setString('last_auto_backup_date', now.toIso8601String());
      await prefs.setString('last_auto_backup_display', DateFormat('MMM dd, yyyy · HH:mm').format(now));
    } catch (e) {
      debugPrint('Auto-backup error: $e');
    }
  }

  /// Collects `photoPath` values from daily meal log JSON (customSlots + legacy slots).
  static void _collectMealLogPhotoPaths(
    Map<String, dynamic> mealLogsBox,
    Set<String> photosToBackup,
  ) {
    for (final entry in mealLogsBox.values) {
      try {
        final logMap = jsonDecode(entry.toString()) as Map<String, dynamic>;
        _forEachMealSlot(logMap, (slot) {
          final path = slot['photoPath'];
          if (path is String && path.isNotEmpty) {
            photosToBackup.add(path);
          }
        });
      } catch (_) {}
    }
  }

  /// Opens a Hive box for backup/restore. Must use [Box]<String> (not untyped
  /// [Hive.box]) — untyped access is Box<dynamic> and throws if the box was
  /// already opened as Box<String>.
  static Future<Box<String>> _openHiveBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }
    try {
      return await Hive.openBox<String>(boxName);
    } catch (_) {
      return Hive.box<String>(boxName);
    }
  }

  /// Rewrites meal slot `photoPath`s using [oldPathMap] (basename → restored path).
  /// Returns true if any path was updated.
  static bool _rewriteMealLogPhotoPaths(
    Map<String, dynamic> logMap,
    Map<String, String> oldPathMap,
  ) {
    var changed = false;
    _forEachMealSlot(logMap, (slot) {
      final path = slot['photoPath'];
      if (path is! String || path.isEmpty) return;
      final fileName = File(path).uri.pathSegments.last;
      final newPath = oldPathMap[fileName];
      if (newPath != null && newPath != path) {
        slot['photoPath'] = newPath;
        changed = true;
      }
    });
    return changed;
  }

  static void _forEachMealSlot(
    Map<String, dynamic> logMap,
    void Function(Map<String, dynamic> slot) onSlot,
  ) {
    for (final legacy in const ['breakfast', 'lunch', 'snack', 'dinner']) {
      final slot = logMap[legacy];
      if (slot is Map<String, dynamic>) onSlot(slot);
    }
    final custom = logMap['customSlots'];
    if (custom is Map) {
      for (final value in custom.values) {
        if (value is Map<String, dynamic>) onSlot(value);
      }
    }
  }
}
